#if os(macOS)
import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers
import OpsNotchCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []
    @Published private(set) var settings = ShelfSettings()
    @Published var query = ""
    @Published var selection: Set<UUID> = []
    @Published var toast: String?
    @Published var editorDraft: ItemDraft?
    @Published var shelfHovered = false

    let store: ShelfStoreService
    var settingsDidChange: (() -> Void)?
    var shelfHoverChanged: ((Bool) -> Void)?

    private var toastWorkItem: DispatchWorkItem?
    private var lastSelectionID: UUID?

    init(store: ShelfStoreService) {
        self.store = store
        reload()
    }

    var language: AppLanguage { settings.language }
    var grouped: (pinned: [ShelfItem], recent: [ShelfItem]) { ShelfLogic.grouped(items, query: query) }
    var visibleItems: [ShelfItem] { grouped.pinned + grouped.recent }

    func reload() {
        do {
            let value = try store.load()
            items = value.items
            settings = value.settings
            selection = selection.intersection(Set(items.map(\.id)))
        } catch {
            showToast(error.localizedDescription)
        }
    }

    func updateSettings(_ change: (inout ShelfSettings) -> Void) {
        var next = settings
        change(&next)
        do {
            let storeValue = try store.updateSettings(next)
            settings = storeValue.settings
            items = storeValue.items
            settingsDidChange?()
        } catch { showToast(error.localizedDescription) }
    }

    func showToast(_ message: String) {
        toastWorkItem?.cancel()
        toast = message
        let work = DispatchWorkItem { [weak self] in self?.toast = nil }
        toastWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25, execute: work)
    }

    func addText(_ text: String, title: String? = nil, toast: Bool = true) {
        do {
            let value = try store.addText(text, title: title)
            apply(value)
            if toast { showToast(L10n.text("clipboardCaught", language)) }
        } catch { showToast(error.localizedDescription) }
    }

    func addURL(_ text: String, title: String? = nil) {
        do { apply(try store.addURL(text, title: title)) }
        catch { showToast(error.localizedDescription) }
    }

    func addSafeAction(title: String, content: String, kind: SafeActionKind) {
        do { apply(try store.addAction(title: title, content: content, kind: kind)) }
        catch { showToast(L10n.text("invalidAction", language)) }
    }

    func addPaths(_ urls: [URL], forcedKind: ShelfKind? = nil) {
        for url in urls {
            do { apply(try store.addPath(url, mode: settings.addMode, forcedKind: forcedKind)) }
            catch { showToast(error.localizedDescription) }
        }
    }

    func addApplication(_ url: URL) {
        do { apply(try store.addApplication(url)) }
        catch { showToast(error.localizedDescription) }
    }

    func togglePin(_ item: ShelfItem) {
        do { apply(try store.setPinned(id: item.id, pinned: !item.pinned)) }
        catch { showToast(error.localizedDescription) }
    }

    func remove(_ ids: Set<UUID>) {
        do {
            apply(try store.remove(ids: ids))
            selection.subtract(ids)
        } catch { showToast(error.localizedDescription) }
    }

    func clearRecent() {
        do { apply(try store.clearRecent()) }
        catch { showToast(error.localizedDescription) }
    }

    func saveDraft(_ draft: ItemDraft) {
        switch draft.mode {
        case .newText: addText(draft.content, title: draft.title, toast: false)
        case .newURL: addURL(draft.content, title: draft.title)
        case .newAction:
            addSafeAction(title: draft.title, content: draft.content, kind: draft.actionKind)
        case .edit(let id):
            do { apply(try store.edit(id: id, title: draft.title, content: draft.content)) }
            catch { showToast(error.localizedDescription) }
        }
        editorDraft = nil
    }

    func beginEdit(_ item: ShelfItem) {
        editorDraft = ItemDraft(
            mode: .edit(item.id),
            title: item.title,
            content: item.content,
            actionKind: item.actionKind ?? .openPath
        )
    }

    func toggleSelection(_ item: ShelfItem) {
        let flags = NSEvent.modifierFlags
        let ordered = visibleItems
        if flags.contains(.shift), let last = lastSelectionID,
           let a = ordered.firstIndex(where: { $0.id == last }),
           let b = ordered.firstIndex(where: { $0.id == item.id }) {
            let range = min(a, b)...max(a, b)
            for index in range { selection.insert(ordered[index].id) }
        } else if flags.contains(.command) {
            if selection.contains(item.id) { selection.remove(item.id) } else { selection.insert(item.id) }
            lastSelectionID = item.id
        } else {
            selection.removeAll()
            lastSelectionID = nil
        }
    }

    func selectedItems(including item: ShelfItem) -> [ShelfItem] {
        guard selection.contains(item.id), selection.count > 1 else { return [item] }
        return visibleItems.filter { selection.contains($0.id) }
    }

    func copySelected(using clipboard: ClipboardManager) {
        let selected = visibleItems.filter { selection.contains($0.id) }
        let text = ShelfLogic.copyText(items: selected)
        guard !text.isEmpty else { return }
        clipboard.copyFromApp(text)
        showToast(L10n.text("copied", language))
    }

    func setShelfHovered(_ hovered: Bool) {
        shelfHovered = hovered
        shelfHoverChanged?(hovered)
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK { addPaths(panel.urls) }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK { addPaths(panel.urls) }
    }

    func chooseApplication() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "app") ?? .application]
        if panel.runModal() == .OK, let url = panel.url { addApplication(url) }
    }

    private func apply(_ storeValue: ShelfStore) {
        items = storeValue.items
        settings = storeValue.settings
    }
}

enum ItemDraftMode: Equatable {
    case newText
    case newURL
    case newAction
    case edit(UUID)
}

struct ItemDraft: Identifiable, Equatable {
    let id = UUID()
    var mode: ItemDraftMode
    var title: String
    var content: String
    var actionKind: SafeActionKind

    static func text() -> ItemDraft { .init(mode: .newText, title: "", content: "", actionKind: .openPath) }
    static func url() -> ItemDraft { .init(mode: .newURL, title: "", content: "https://", actionKind: .openURL) }
    static func action() -> ItemDraft { .init(mode: .newAction, title: "", content: "", actionKind: .openPath) }
}
#endif

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
    @Published private(set) var appContext: AppContextKind = .generic
    @Published private(set) var localFileResults: [LocalFileCandidate] = []
    @Published var query = "" {
        didSet {
            scheduleLocalFileSearch()
            resetQuickHighlight()
        }
    }
    /// 类型筛选(全部/文件/文本/URL/应用),与搜索词叠加;仅会话内有效,不落盘。
    @Published var kindFilter: ShelfKindFilter = .all {
        didSet {
            scheduleLocalFileSearch()
            resetQuickHighlight()
        }
    }
    @Published var selection: Set<UUID> = []
    @Published var toast: String?
    @Published var editorDraft: ItemDraft?
    @Published var shelfHovered = false
    /// 键盘流焦点请求令牌:ShelfWindowController 置为新 UUID 时,ShelfView 的搜索框应自动聚焦。
    @Published var focusRequestToken: UUID?
    /// Finder / Working Set / Shelf / Local Search 共用的一套键盘高亮 ID。
    @Published var highlightedQuickEntryID: String?

    let store: ShelfStoreService
    var settingsDidChange: (() -> Void)?
    var shelfHoverChanged: ((Bool) -> Void)?
    var requestHide: (() -> Void)?
    var requestDelayedHide: (() -> Void)?
    var requestOpenFinderPath: ((String, UUID?) -> Void)?
    var hotkeyApply: ((HotkeyShortcut?) -> HotkeyError?)?
    @Published var hotkeyConflict = false

    private var toastWorkItem: DispatchWorkItem?
    private var lastSelectionID: UUID?
    private var localSearchTask: Task<Void, Never>?

    init(store: ShelfStoreService) {
        self.store = store
        reload()
    }

    var language: AppLanguage { settings.language }

    var workingSetItems: [ShelfItem] {
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let orderedByWorkingSet = settings.workingSetItemIDs.compactMap { byID[$0] }
        return SmartShelfRanking.ordered(
            orderedByWorkingSet,
            query: query,
            kindFilter: kindFilter,
            appContext: appContext
        )
    }

    var grouped: (pinned: [ShelfItem], recent: [ShelfItem]) {
        let workingIDs = Set(settings.workingSetItemIDs)
        let remaining = items.filter { !workingIDs.contains($0.id) }
        let pinned = SmartShelfRanking.ordered(
            remaining.filter(\.pinned),
            query: query,
            kindFilter: kindFilter,
            appContext: appContext
        )
        let recent = SmartShelfRanking.ordered(
            remaining.filter { !$0.pinned },
            query: query,
            kindFilter: kindFilter,
            appContext: appContext
        )
        return (pinned, recent)
    }

    var visibleItems: [ShelfItem] {
        let groups = grouped
        return workingSetItems + groups.pinned + groups.recent
    }

    /// Finder 快捷路径只在“全部/文件”中出现，并与 Shelf 共用搜索框。
    var visibleFinderEntries: [QuickShelfEntry] {
        guard kindFilter == .all || kindFilter == .file else { return [] }

        var entries: [QuickShelfEntry] = []
        let defaultPath = expandedFinderPath(settings.finderDefaultPath)
        let defaultTitle = L10n.text("finderDefaultPath", language)
        if finderMatches(title: defaultTitle, path: defaultPath) {
            entries.append(.finder(
                id: QuickShelfEntry.finderDefaultID,
                title: defaultTitle,
                path: defaultPath,
                quickPathID: nil
            ))
        }

        for ranked in FinderQuickPathRanking.ranked(settings.finderQuickPaths) {
            let path = expandedFinderPath(ranked.item.path)
            guard finderMatches(title: ranked.item.label, path: path) else { continue }
            entries.append(.finder(
                id: QuickShelfEntry.finderID(ranked.item.id),
                title: ranked.item.label,
                path: path,
                quickPathID: ranked.item.id
            ))
        }
        return entries
    }

    var visibleLocalEntries: [QuickShelfEntry] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              kindFilter == .all || kindFilter == .file else { return [] }

        let shelfPaths = Set(items.compactMap { item -> String? in
            guard [.file, .folder, .application].contains(item.kind) else { return nil }
            return standardizedPath(item.content)
        })
        let finderPaths = Set(visibleFinderEntries.compactMap { $0.finderPath }.map(standardizedPath))

        return localFileResults.compactMap { candidate in
            let standardized = standardizedPath(candidate.path)
            guard !shelfPaths.contains(standardized), !finderPaths.contains(standardized) else { return nil }
            return .local(
                id: QuickShelfEntry.localID(path: standardized),
                title: candidate.title,
                path: standardized,
                isDirectory: candidate.isDirectory
            )
        }
    }

    var visibleQuickEntries: [QuickShelfEntry] {
        visibleFinderEntries
            + visibleItems.map(QuickShelfEntry.shelf)
            + visibleLocalEntries
    }

    func quickEntryID(for item: ShelfItem) -> String {
        QuickShelfEntry.shelfID(item.id)
    }

    func semanticKind(for item: ShelfItem) -> SemanticKind {
        ShelfSemantic.kind(for: item)
    }

    func refreshSmartContext() {
        let next = AppContextResolver.current()
        if appContext != next {
            appContext = next
            resetQuickHighlight()
        }
        scheduleLocalFileSearch()
    }

    func moveHighlight(_ delta: Int) {
        let visible = visibleQuickEntries
        guard !visible.isEmpty else {
            highlightedQuickEntryID = nil
            return
        }
        let index = visible.firstIndex { $0.id == highlightedQuickEntryID } ?? -1
        let next = min(max(index + delta, 0), visible.count - 1)
        highlightedQuickEntryID = visible[next].id
    }

    /// Enter：Finder/Local Folder 打开目录；Shelf/Local File 维持正确 pasteboard 语义。
    func confirmHighlight(using clipboard: ClipboardManager) {
        guard let entry = highlightedQuickEntry else { return }
        switch entry {
        case .finder(_, _, let path, let quickPathID):
            requestOpenFinderPath?(path, quickPathID)
        case .shelf(let item):
            let payload = ShelfLogic.copyPayload(items: [item])
            guard !payload.isEmpty else { return }
            clipboard.copyPayload(payload)
            recordUse(item.id)
            showToast(L10n.text("copied", language))
            requestDelayedHide?()
        case .local(_, _, let path, let isDirectory):
            if isDirectory {
                requestOpenFinderPath?(path, nil)
            } else {
                clipboard.copyPayload(ShelfCopyPayload(filePaths: [path]))
                showToast(L10n.text("copied", language))
                requestDelayedHide?()
            }
        }
    }

    func openFinderEntry(_ entry: QuickShelfEntry) {
        guard case .finder(_, _, let path, let quickPathID) = entry else { return }
        requestOpenFinderPath?(path, quickPathID)
    }

    func openLocalEntry(_ entry: QuickShelfEntry, using clipboard: ClipboardManager) {
        guard case .local(_, _, let path, let isDirectory) = entry else { return }
        if isDirectory {
            requestOpenFinderPath?(path, nil)
        } else {
            clipboard.copyPayload(ShelfCopyPayload(filePaths: [path]))
            showToast(L10n.text("copied", language))
        }
    }

    func highlightFinderDefault() {
        if visibleFinderEntries.contains(where: { $0.id == QuickShelfEntry.finderDefaultID }) {
            highlightedQuickEntryID = QuickShelfEntry.finderDefaultID
        } else {
            resetQuickHighlight()
        }
    }

    func resetQuickHighlight() {
        highlightedQuickEntryID = visibleQuickEntries.first?.id
    }

    func escapeShelf() {
        requestHide?()
    }

    func setKindFilter(to filter: ShelfKindFilter) {
        kindFilter = filter
    }

    func quickLookHighlighted() {
        guard let entry = highlightedQuickEntry else { return }
        switch entry {
        case .shelf(let item):
            guard ItemPreviewKind.isPreviewable(item) else { return }
            QuickLookService.shared.preview(item)
        case .local(_, let title, let path, let isDirectory):
            guard !isDirectory else { return }
            let item = ShelfItem(kind: .file, title: title, content: path, storageMode: .reference)
            QuickLookService.shared.preview(item)
        case .finder:
            return
        }
    }

    func reload() {
        do {
            let value = try store.load()
            items = value.items
            settings = value.settings
            selection = selection.intersection(Set(items.map(\.id)))
            if highlightedQuickEntryID != nil,
               !visibleQuickEntries.contains(where: { $0.id == highlightedQuickEntryID }) {
                resetQuickHighlight()
            }
            scheduleLocalFileSearch()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    /// 保存设置。Working Set 仅是 Quick Shelf 数据状态，可选择不触发 Sensor/热键/Finder 等系统设置重载。
    func updateSettings(notifyServices: Bool = true, _ change: (inout ShelfSettings) -> Void) {
        var next = settings
        change(&next)
        do {
            let storeValue = try store.updateSettings(next)
            settings = storeValue.settings
            items = storeValue.items
            if highlightedQuickEntryID != nil,
               !visibleQuickEntries.contains(where: { $0.id == highlightedQuickEntryID }) {
                resetQuickHighlight()
            }
            if notifyServices { settingsDidChange?() }
            scheduleLocalFileSearch()
        } catch { showToast(error.localizedDescription) }
    }

    func setHotkey(_ shortcut: HotkeyShortcut?) {
        guard let hotkeyApply else { return }
        if let _ = hotkeyApply(shortcut) {
            hotkeyConflict = true
            return
        }
        hotkeyConflict = false
        updateSettings { $0.hotkey = shortcut }
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

    func isInWorkingSet(_ item: ShelfItem) -> Bool {
        settings.workingSetItemIDs.contains(item.id)
    }

    func toggleWorkingSet(_ item: ShelfItem) {
        updateSettings(notifyServices: false) { settings in
            if let index = settings.workingSetItemIDs.firstIndex(of: item.id) {
                settings.workingSetItemIDs.remove(at: index)
            } else {
                settings.workingSetItemIDs.insert(item.id, at: 0)
                settings.workingSetItemIDs = Array(settings.workingSetItemIDs.prefix(64))
            }
        }
        showToast(L10n.text(isInWorkingSet(item) ? "workingSetAdded" : "workingSetRemoved", language))
    }

    func clearWorkingSet() {
        updateSettings(notifyServices: false) { $0.workingSetItemIDs.removeAll() }
        showToast(L10n.text("workingSetCleared", language))
    }

    /// V1 兼容入口：只刷新 updatedAt。
    func touchItem(_ id: UUID) {
        do { apply(try store.touch(id: id)) }
        catch { showToast(error.localizedDescription) }
    }

    /// V2：成功使用后累计 useCount / lastUsedAt，并维持最近上浮行为。
    func recordUse(_ id: UUID) {
        do { apply(try store.recordUse(id: id)) }
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
        let payload = ShelfLogic.copyPayload(items: selected)
        guard !payload.isEmpty else { return }
        clipboard.copyPayload(payload)
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

    private var highlightedQuickEntry: QuickShelfEntry? {
        guard let id = highlightedQuickEntryID else { return nil }
        return visibleQuickEntries.first(where: { $0.id == id })
    }

    private func finderMatches(title: String, path: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(trimmed)
            || path.localizedCaseInsensitiveContains(trimmed)
    }

    private func expandedFinderPath(_ rawPath: String) -> String {
        NSString(string: rawPath).expandingTildeInPath
    }

    private func standardizedPath(_ rawPath: String) -> String {
        NSString(string: NSString(string: rawPath).expandingTildeInPath).standardizingPath
    }

    private func scheduleLocalFileSearch() {
        localSearchTask?.cancel()
        localFileResults = []

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              kindFilter == .all || kindFilter == .file else { return }

        let recent = LocalFileSearchService.recentDocumentPaths()
        let shelfPaths = items.compactMap { item -> String? in
            [.file, .folder, .application].contains(item.kind) ? item.content : nil
        }
        let finderPaths = [settings.finderDefaultPath] + settings.finderQuickPaths.map(\.path)
        let expectedQuery = trimmed

        localSearchTask = Task { [weak self] in
            let results = await LocalFileSearchService.search(
                query: expectedQuery,
                recentDocumentPaths: recent,
                shelfPaths: shelfPaths,
                finderPaths: finderPaths,
                limit: 20
            )
            guard !Task.isCancelled, let self else { return }
            guard self.query.trimmingCharacters(in: .whitespacesAndNewlines) == expectedQuery,
                  self.kindFilter == .all || self.kindFilter == .file else { return }
            self.localFileResults = results
            if self.highlightedQuickEntryID == nil {
                self.resetQuickHighlight()
            }
        }
    }

    private func apply(_ storeValue: ShelfStore) {
        let knownIDs = Set(items.map(\.id))
        items = storeValue.items
        settings = storeValue.settings
        if kindFilter != .all {
            let incoming = storeValue.items.filter { !knownIDs.contains($0.id) }
            if incoming.contains(where: { !ShelfLogic.matches($0, query: "", kindFilter: kindFilter) }) {
                kindFilter = .all
            }
        }
        if highlightedQuickEntryID == nil
            || !visibleQuickEntries.contains(where: { $0.id == highlightedQuickEntryID }) {
            resetQuickHighlight()
        }
        scheduleLocalFileSearch()
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

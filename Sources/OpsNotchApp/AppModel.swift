#if os(macOS)
import AppKit
import Combine
import Foundation
import OpsNotchCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var items: [ShelfItem] = [] {
        didSet { invalidateQuickShelfSnapshot() }
    }
    @Published private(set) var settings = ShelfSettings() {
        didSet { invalidateQuickShelfSnapshot() }
    }
    let experience = ShelfExperienceModel()
    let snapshotProvider = ShelfSnapshotProvider()

    // Transitional service adapters; all session storage lives in experience.
    var appContext: AppContextKind { experience.appContext }
    var query: String {
        get { experience.query }
        set { experience.query = newValue }
    }
    var kindFilter: ShelfKindFilter {
        get { experience.kindFilter }
        set { experience.kindFilter = newValue }
    }
    var selection: Set<UUID> {
        get { experience.selection }
        set { experience.selection = newValue }
    }
    var toast: String? {
        get { experience.toast }
        set { experience.toast = newValue }
    }
    var editorDraft: ItemDraft? {
        get { experience.editorDraft }
        set { experience.editorDraft = newValue }
    }
    var shelfHovered: Bool {
        get { experience.shelfHovered }
        set { experience.shelfHovered = newValue }
    }
    var focusRequestToken: UUID? {
        get { experience.focusRequestToken }
        set { experience.focusRequestToken = newValue }
    }
    var highlightedQuickEntryID: String? {
        get { experience.highlightedQuickEntryID }
        set { experience.highlightedQuickEntryID = newValue }
    }
    var hotkeyConflict: Bool {
        get { experience.hotkeyConflict }
        set { experience.hotkeyConflict = newValue }
    }

    let store: ShelfStoreService
    var settingsDidChange: (() -> Void)?
    var shelfHoverChanged: ((Bool) -> Void)? {
        get { experience.shelfHoverChanged }
        set { experience.shelfHoverChanged = newValue }
    }
    var requestHide: (() -> Void)?
    var requestDelayedHide: (() -> Void)?
    var requestOpenFinderPath: ((String, UUID?) -> Void)?
    var requestDesktopCommand: ((DesktopCommand) -> Void)?
    var hotkeyApply: ((HotkeyShortcut?) -> HotkeyError?)?

    init(store: ShelfStoreService) {
        self.store = store
        experience.snapshotInputsDidChange = { [weak self] in self?.snapshotProvider.invalidate() }
        experience.snapshot = { [weak self] in self?.quickShelfSnapshot }
        reload()
    }

    var language: AppLanguage { settings.language }

    var workingSetItems: [ShelfItem] {
        quickShelfSnapshot.itemSnapshot.working
    }

    var grouped: (pinned: [ShelfItem], recent: [ShelfItem]) {
        let snapshot = quickShelfSnapshot.itemSnapshot
        return (snapshot.pinned, snapshot.recent)
    }

    var visibleItems: [ShelfItem] {
        quickShelfSnapshot.visibleShelfItems
    }

    /// Finder 快捷路径只在“全部/文件”中出现，并与 Shelf 共用搜索框。
    var visibleFinderEntries: [QuickShelfEntry] {
        quickShelfSnapshot.finderEntries
    }

    /// 本机文件系统搜索已移除；保留空集合用于兼容现有 Quick Shelf 视图结构。
    var visibleLocalEntries: [QuickShelfEntry] {
        quickShelfSnapshot.localEntries
    }

    var visibleDesktopEntries: [QuickShelfEntry] {
        quickShelfSnapshot.desktopEntries
    }

    var visibleQuickEntries: [QuickShelfEntry] {
        quickShelfSnapshot.visibleEntries
    }

    var quickShelfSnapshot: ShelfSnapshot {
        snapshotProvider.snapshot(items: items, settings: settings, experience: experience)
    }

    private func invalidateQuickShelfSnapshot() { snapshotProvider.invalidate() }

    func quickEntryID(for item: ShelfItem) -> String {
        QuickShelfEntry.shelfID(item.id)
    }

    func semanticKind(for item: ShelfItem) -> SemanticKind {
        ShelfSemantic.kind(for: item)
    }

    func refreshSmartContext() {
        experience.refreshContext(AppContextResolver.current())
    }

    func moveHighlight(_ delta: Int) { experience.moveHighlight(delta) }

    /// 左右键跨功能区跳转：← 智能最近首条；→ Finder 快捷目录首条。
    /// 目标功能区当前不可见或为空时保持原高亮，避免意外跳到其他区域。
    func moveHorizontalHighlight(_ direction: QuickShelfHorizontalDirection) { experience.moveHorizontalHighlight(direction) }

    /// Enter：Finder 打开目录；Shelf 维持正确 pasteboard 语义。
    func confirmHighlight(using clipboard: ClipboardManager) {
        guard let entry = highlightedQuickEntry else { return }
        switch entry {
        case .desktop(_, _, _, let command):
            requestDesktopCommand?(command)
        case .finder(_, _, let path, let quickPathID):
            requestOpenFinderPath?(path, quickPathID)
        case .shelf(let item):
            if item.clipboardImage {
                guard clipboard.copyImageFile(item.content) else { return }
                recordUse(item.id)
                showToast(L10n.text("copied", language))
                requestDelayedHide?()
                return
            }
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

    func highlightFinderDefault() { experience.highlightFinderDefault() }

    func resetQuickHighlight() { experience.resetQuickHighlight() }

    func escapeShelf() {
        requestHide?()
    }

    func setKindFilter(to filter: ShelfKindFilter) {
        kindFilter = filter
    }

    /// Space 预览：文件/目录走系统 Quick Look，文本走现有悬浮预览。
    /// 返回是否真正处理了快捷键；未处理时调用方应把按键继续交给搜索框。
    @discardableResult
    func quickLookHighlighted() -> Bool {
        guard let entry = highlightedQuickEntry else { return false }
        switch entry {
        case .desktop, .finder:
            return false
        case .shelf(let item):
            switch item.kind {
            case .file, .folder:
                guard FileManager.default.fileExists(atPath: item.content) else { return false }
                QuickLookService.shared.preview(item)
                return true
            case .text:
                guard ItemPreviewKind.isPreviewable(item) else { return false }
                FloatingPreviewController.shared.show(item: item, language: language)
                return true
            case .url, .application, .action:
                return false
            }
        case .local(_, let title, let path, let isDirectory):
            guard !isDirectory, FileManager.default.fileExists(atPath: path) else { return false }
            let item = ShelfItem(kind: .file, title: title, content: path, storageMode: .reference)
            QuickLookService.shared.preview(item)
            return true
        }
    }

    var canPreviewHighlighted: Bool {
        guard let entry = highlightedQuickEntry else { return false }
        switch entry {
        case .desktop, .finder:
            return false
        case .shelf(let item):
            switch item.kind {
            case .file, .folder:
                return FileManager.default.fileExists(atPath: item.content)
            case .text:
                return ItemPreviewKind.isPreviewable(item)
            case .url, .application, .action:
                return false
            }
        case .local(_, _, let path, let isDirectory):
            return !isDirectory && FileManager.default.fileExists(atPath: path)
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

    func showToast(_ message: String) { experience.showToast(message) }

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

    func addPaths(_ urls: [URL], forcedKind: ShelfKind? = nil, sourceAppName: String? = nil) {
        for url in urls {
            do { apply(try store.addPath(url, mode: settings.addMode, forcedKind: forcedKind, sourceAppName: sourceAppName)) }
            catch { showToast(error.localizedDescription) }
        }
    }

    func addApplication(_ url: URL, sourceAppName: String? = nil) {
        do { apply(try store.addApplication(url, sourceAppName: sourceAppName)) }
        catch { showToast(error.localizedDescription) }
    }

    func togglePin(_ item: ShelfItem) {
        // 行视图中的 ShelfItem 是值类型快照。重复剪贴板捕获会刷新同一 ID 的条目并触发重排，
        // 因此 toggle 必须以 AppModel 当前 items 为事实来源，不能使用点击闭包里可能已过期的 pinned 值。
        guard let current = items.first(where: { $0.id == item.id }) else { return }
        do { apply(try store.setPinned(id: current.id, pinned: !current.pinned)) }
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

    /// 保存编辑器草稿。成功时清空 editorDraft(sheet 随之关闭)并返回 true;
    /// 失败时保持 editorDraft 与用户输入,toast 提示原因并返回 false。
    @discardableResult
    func saveDraft(_ draft: ItemDraft) -> Bool {
        do {
            switch draft.mode {
            case .newText: apply(try store.addText(draft.content, title: draft.title))
            case .newURL: apply(try store.addURL(draft.content, title: draft.title))
            case .newAction: apply(try store.addAction(title: draft.title, content: draft.content, kind: draft.actionKind))
            case .edit(let id): apply(try store.edit(id: id, title: draft.title, content: draft.content))
            }
            editorDraft = nil
            return true
        } catch ShelfStoreError.unsafeAction {
            showToast(L10n.text("invalidAction", language))
            return false
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    func beginEdit(_ item: ShelfItem) {
        editorDraft = ItemDraft(
            mode: .edit(item.id),
            title: item.title,
            content: item.content,
            actionKind: item.actionKind ?? .openPath
        )
    }

    func toggleSelection(_ item: ShelfItem) { experience.toggleSelection(item) }

    func selectedItems(including item: ShelfItem) -> [ShelfItem] { experience.selectedItems(including: item) }

    func copySelected(using clipboard: ClipboardManager) {
        let selected = visibleItems.filter { selection.contains($0.id) }
        if selected.count == 1, let item = selected.first, item.clipboardImage {
            guard clipboard.copyImageFile(item.content) else { return }
            recordUse(item.id)
            showToast(L10n.text("copied", language))
            return
        }
        let payload = ShelfLogic.copyPayload(items: selected)
        guard !payload.isEmpty else { return }
        clipboard.copyPayload(payload)
        showToast(L10n.text("copied", language))
    }

    func setShelfHovered(_ hovered: Bool) { experience.setShelfHovered(hovered) }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        // 应用未激活时模态面板会呈灰色禁用态,先激活再弹出。
        NSApplication.shared.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK { addPaths(panel.urls) }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        NSApplication.shared.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK { addPaths(panel.urls) }
    }

    func chooseApplication() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        NSApplication.shared.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url { addApplication(url) }
    }

    var highlightedShelfItem: ShelfItem? {
        guard case .shelf(let item) = highlightedQuickEntry else { return nil }
        return item
    }

    @discardableResult
    func togglePinHighlighted() -> Bool {
        guard let item = highlightedShelfItem else { return false }
        togglePin(item)
        return true
    }

    @discardableResult
    func removeHighlighted() -> Bool {
        guard let item = highlightedShelfItem else { return false }
        remove(Set([item.id]))
        resetQuickHighlight()
        return true
    }

    private var highlightedQuickEntry: QuickShelfEntry? {
        guard let id = highlightedQuickEntryID else { return nil }
        return quickShelfSnapshot.entryByID[id]
    }


    /// 模块内可见(而非 private),供同模块扩展(剪贴板/拖入捕获)直接应用 store 返回值。
    func apply(_ storeValue: ShelfStore) {
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
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
    @Published var query = "" {
        didSet {
            // 过滤结果变化后,高亮回落到新的第一行。
            highlightedID = visibleItems.first?.id
        }
    }
    /// 类型筛选(全部/文件/文本/URL/应用),与搜索词叠加;仅会话内有效,不落盘。
    @Published var kindFilter: ShelfKindFilter = .all {
        didSet {
            // 与 query.didSet 同规则:过滤结果变化后高亮回落首行。
            highlightedID = visibleItems.first?.id
        }
    }
    @Published var selection: Set<UUID> = []
    @Published var toast: String?
    @Published var editorDraft: ItemDraft?
    @Published var shelfHovered = false
    /// 键盘流焦点请求令牌:ShelfWindowController 置为新 UUID 时,ShelfView 的搜索框应自动聚焦。
    /// 面板隐藏时清空,保证每次热键呼出都触发一次新的聚焦。
    @Published var focusRequestToken: UUID?
    /// 键盘流当前高亮行,与多选 selection 语义/样式相互独立。
    @Published var highlightedID: UUID?

    let store: ShelfStoreService
    var settingsDidChange: (() -> Void)?
    var shelfHoverChanged: ((Bool) -> Void)?
    /// Esc:立即收起面板。
    var requestHide: (() -> Void)?
    /// Enter 复制后:短暂延迟收起面板(给 toast 留显示时间)。
    var requestDelayedHide: (() -> Void)?
    /// 设置页写入快捷键的通道:先注册后落盘,注册失败(组合键被占用)不持久化。
    /// 由 AppDelegate 注入 HotkeyService.apply。
    var hotkeyApply: ((HotkeyShortcut?) -> HotkeyError?)?
    /// 最近一次快捷键写入是否因注册冲突被拒绝,设置页据此显示红字提示。
    @Published var hotkeyConflict = false

    private var toastWorkItem: DispatchWorkItem?
    private var lastSelectionID: UUID?

    init(store: ShelfStoreService) {
        self.store = store
        reload()
    }

    var language: AppLanguage { settings.language }
    var grouped: (pinned: [ShelfItem], recent: [ShelfItem]) { ShelfLogic.grouped(items, query: query, kindFilter: kindFilter) }
    var visibleItems: [ShelfItem] { grouped.pinned + grouped.recent }

    func moveHighlight(_ delta: Int) {
        let visible = visibleItems
        guard !visible.isEmpty else {
            highlightedID = nil
            return
        }
        let index = visible.firstIndex { $0.id == highlightedID } ?? -1
        let next = min(max(index + delta, 0), visible.count - 1)
        highlightedID = visible[next].id
    }

    /// Enter:复制高亮条目(只写剪贴板,不执行任何打开动作),刷新上浮并收起面板。
    func confirmHighlight(using clipboard: ClipboardManager) {
        guard let id = highlightedID,
              let item = visibleItems.first(where: { $0.id == id }) else { return }
        clipboard.copyFromApp(item.content)
        touchItem(id)
        showToast(L10n.text("copied", language))
        requestDelayedHide?()
    }

    func escapeShelf() {
        requestHide?()
    }

    /// ⌘1~⌘5 与筛选 chips 共用的切换入口;didSet 负责高亮回落。
    func setKindFilter(to filter: ShelfKindFilter) {
        kindFilter = filter
    }

    /// Space:Quick Look 预览键盘高亮条目(仅可预览类型),面板保持展开、不写剪贴板。
    func quickLookHighlighted() {
        guard let id = highlightedID,
              let item = visibleItems.first(where: { $0.id == id }),
              ItemPreviewKind.isPreviewable(item) else { return }
        QuickLookService.shared.preview(item)
    }

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

    /// 设置页写入快捷键:先经 HotkeyService 注册(消费型全局热键),失败则拒绝并提示冲突,
    /// 保持原快捷键继续生效;成功才持久化。nil 表示清除。
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

    /// 复制成功后刷新条目最近使用时间,使其按排序规则上浮到所在分区顶部。
    func touchItem(_ id: UUID) {
        do { apply(try store.touch(id: id)) }
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
        let knownIDs = Set(items.map(\.id))
        items = storeValue.items
        settings = storeValue.settings
        // 新条目若会被当前类型筛选隐藏,筛选回到"全部",保证刚放入的条目可见。
        if kindFilter != .all {
            let incoming = storeValue.items.filter { !knownIDs.contains($0.id) }
            if incoming.contains(where: { !ShelfLogic.matches($0, query: "", kindFilter: kindFilter) }) {
                kindFilter = .all
            }
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

#if os(macOS)
import AppKit
import Combine
import OpsNotchCore

/// Session state has one owner; services may temporarily forward through AppModel.
@MainActor
final class ShelfExperienceModel: ObservableObject {
    @Published private(set) var appContext: AppContextKind = .generic {
        didSet { snapshotInputsDidChange?() }
    }
    @Published var query = "" {
        didSet {
            // Invalidate before looking up the first result of the new query/filter.
            snapshotInputsDidChange?()
            resetQuickHighlight()
        }
    }
    /// 类型筛选(全部/文件/文本/URL/应用),与搜索词叠加;仅会话内有效,不落盘。
    @Published var kindFilter: ShelfKindFilter = .all {
        didSet {
            // Invalidate before looking up the first result of the new query/filter.
            snapshotInputsDidChange?()
            resetQuickHighlight()
        }
    }
    var commandSearchScope: CommandSearchScope {
        CommandSearchScope(query: query, kindFilter: kindFilter)
    }

    @Published var selection: Set<UUID> = []
    @Published var toast: String?
    @Published var editorDraft: ItemDraft?
    @Published var shelfHovered = false
    /// 键盘流焦点请求令牌:ShelfWindowController 置为新 UUID 时,ShelfView 的搜索框应自动聚焦。
    @Published var focusRequestToken: UUID?
    /// Finder / Working Set / Shelf 共用的一套键盘高亮 ID。
    @Published var highlightedQuickEntryID: String?

    @Published var hotkeyConflict = false
    var snapshotInputsDidChange: (() -> Void)?
    var snapshot: (() -> ShelfSnapshot?)?
    var shelfHoverChanged: ((Bool) -> Void)?
    private var toastWorkItem: DispatchWorkItem?
    private var lastSelectionID: UUID?

    deinit { toastWorkItem?.cancel() }

    private var visibleQuickEntries: [QuickShelfEntry] { snapshot?()?.visibleEntries ?? [] }
    private var visibleFinderEntries: [QuickShelfEntry] { snapshot?()?.finderEntries ?? [] }
    private var visibleItems: [ShelfItem] { snapshot?()?.itemSnapshot.visibleItems ?? [] }
    private var recentItems: [ShelfItem] { snapshot?()?.itemSnapshot.recent ?? [] }

    /// A new context session refreshes time-sensitive recency without periodic work.
    /// Ordinary highlight, selection and focus changes do not start a new session.
    func refreshContext(_ next: AppContextKind) {
        if appContext != next {
            appContext = next
            resetQuickHighlight()
        } else {
            snapshotInputsDidChange?()
        }
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

    func moveHorizontalHighlight(_ direction: QuickShelfHorizontalDirection) {
        let recentEntryIDs = recentItems.map { QuickShelfEntry.shelfID($0.id) }
        guard let destinationID = QuickShelfKeyboardNavigation.destinationID(
            for: direction,
            finderEntryIDs: visibleFinderEntries.map(\.id),
            recentEntryIDs: recentEntryIDs
        ) else { return }
        highlightedQuickEntryID = destinationID
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

    func showToast(_ message: String) {
        toastWorkItem?.cancel()
        toast = message
        let work = DispatchWorkItem { [weak self] in self?.toast = nil }
        toastWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25, execute: work)
    }

    func setShelfHovered(_ hovered: Bool) {
        shelfHovered = hovered
        shelfHoverChanged?(hovered)
    }
}
#endif

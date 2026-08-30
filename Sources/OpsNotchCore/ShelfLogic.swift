import Foundation

/// 类型筛选位:与搜索词叠加的条目类型收窄。
/// action 条目按其目标类型归入"文件"(openPath)或"URL"(openURL),文件夹归入"文件"。
public enum ShelfKindFilter: Equatable, Hashable, Sendable, CaseIterable {
    case all
    case file
    case text
    case url
    case application
}

public enum ShelfLogic {
    public static func matches(_ item: ShelfItem, query: String, kindFilter: ShelfKindFilter = .all) -> Bool {
        guard matchesKind(item, kindFilter: kindFilter) else { return false }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return item.title.lowercased().contains(q) || item.content.lowercased().contains(q)
    }

    private static func matchesKind(_ item: ShelfItem, kindFilter: ShelfKindFilter) -> Bool {
        switch kindFilter {
        case .all:
            return true
        case .file:
            return item.kind == .file || item.kind == .folder
                || (item.kind == .action && item.actionKind == .openPath)
        case .text:
            return item.kind == .text
        case .url:
            return item.kind == .url || (item.kind == .action && item.actionKind == .openURL)
        case .application:
            return item.kind == .application
        }
    }

    public static func ordered(_ items: [ShelfItem]) -> [ShelfItem] {
        items.sorted {
            if $0.pinned != $1.pinned { return $0.pinned && !$1.pinned }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.createdAt > $1.createdAt
        }
    }

    public static func grouped(_ items: [ShelfItem], query: String = "", kindFilter: ShelfKindFilter = .all) -> (pinned: [ShelfItem], recent: [ShelfItem]) {
        let filtered = ordered(items).filter { matches($0, query: query, kindFilter: kindFilter) }
        return (filtered.filter(\.pinned), filtered.filter { !$0.pinned })
    }

    public static func expiredIDs(items: [ShelfItem], settings: ShelfSettings, now: UInt64 = ShelfClock.now()) -> Set<UUID> {
        guard settings.tempTTLHours > 0 else { return [] }
        let ttl = settings.tempTTLHours * 60 * 60
        return Set(items.compactMap { item in
            guard !item.pinned, now > item.updatedAt, now - item.updatedAt >= ttl else { return nil }
            return item.id
        })
    }

    public static func copyText(items: [ShelfItem]) -> String {
        items.compactMap { item -> String? in
            switch item.kind {
            case .text, .url: return item.content
            default: return nil
            }
        }.joined(separator: "\n")
    }

    /// 系统打开事件(reopen)去抖:应用激活流程可能在极短时间内重复投递打开事件,
    /// 窗口期内的重复事件折叠为一次,保证"展开/收起"切换语义不抖动。
    /// `lastAt == nil` 表示首次事件,必处理;时间基准由调用方选定(单调时钟为宜)。
    public static func shouldHandleOpenEvent(lastAt: TimeInterval?, now: TimeInterval, window: TimeInterval) -> Bool {
        guard let lastAt else { return true }
        return now - lastAt >= window
    }
}

import Foundation

/// 类型筛选位:与搜索词叠加的条目类型收窄,六个分类互斥。
/// action 条目独占"安全操作"分类;文件夹归入"文件"。
public enum ShelfKindFilter: Equatable, Hashable, Sendable, CaseIterable {
    case all
    case file
    case text
    case url
    case application
    case action
}

/// "复制所选"写入系统剪贴板的 payload:文件类条目产出路径列表(写文件 URL flavor),
/// 文字/URL 类条目产出拼接文本(写文本 flavor)。
public struct ShelfCopyPayload: Equatable, Sendable {
    public var filePaths: [String]
    public var text: String?

    public var isEmpty: Bool { filePaths.isEmpty && (text?.isEmpty ?? true) }

    public init(filePaths: [String] = [], text: String? = nil) {
        self.filePaths = filePaths
        self.text = text
    }
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
        case .text:
            return item.kind == .text
        case .url:
            return item.kind == .url
        case .application:
            return item.kind == .application
        case .action:
            return item.kind == .action
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

    public static func copyPayload(items: [ShelfItem]) -> ShelfCopyPayload {
        var filePaths: [String] = []
        var texts: [String] = []
        for item in items {
            switch item.kind {
            case .file, .folder, .application:
                filePaths.append(item.content)
            case .text, .url:
                texts.append(item.content)
            case .action:
                switch item.actionKind {
                case .openPath:
                    filePaths.append(item.content)
                case .openURL, nil:
                    texts.append(item.content)
                }
            }
        }
        return ShelfCopyPayload(filePaths: filePaths, text: texts.isEmpty ? nil : texts.joined(separator: "\n"))
    }
}

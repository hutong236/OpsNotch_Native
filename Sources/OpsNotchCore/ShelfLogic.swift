import Foundation

public enum ShelfLogic {
    public static func matches(_ item: ShelfItem, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return item.title.lowercased().contains(q) || item.content.lowercased().contains(q)
    }

    public static func ordered(_ items: [ShelfItem]) -> [ShelfItem] {
        items.sorted {
            if $0.pinned != $1.pinned { return $0.pinned && !$1.pinned }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.createdAt > $1.createdAt
        }
    }

    public static func grouped(_ items: [ShelfItem], query: String = "") -> (pinned: [ShelfItem], recent: [ShelfItem]) {
        let filtered = ordered(items).filter { matches($0, query: query) }
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
}

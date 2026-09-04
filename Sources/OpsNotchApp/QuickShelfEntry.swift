#if os(macOS)
import Foundation
import OpsNotchCore

/// Quick Shelf 仅用于展示/交互层的统一条目，不进入 shelf.json。
/// Finder、持久化 ShelfItem 与 V2 本地搜索候选共享一套键盘导航 ID。
enum QuickShelfEntry: Identifiable, Equatable {
    case finder(id: String, title: String, path: String, quickPathID: UUID?)
    case shelf(ShelfItem)
    case local(id: String, title: String, path: String, isDirectory: Bool)

    var id: String {
        switch self {
        case .finder(let id, _, _, _):
            return id
        case .shelf(let item):
            return Self.shelfID(item.id)
        case .local(let id, _, _, _):
            return id
        }
    }

    var title: String {
        switch self {
        case .finder(_, let title, _, _): return title
        case .shelf(let item): return item.title
        case .local(_, let title, _, _): return title
        }
    }

    var finderPath: String? {
        guard case .finder(_, _, let path, _) = self else { return nil }
        return path
    }

    var finderQuickPathID: UUID? {
        guard case .finder(_, _, _, let quickPathID) = self else { return nil }
        return quickPathID
    }

    var shelfItem: ShelfItem? {
        guard case .shelf(let item) = self else { return nil }
        return item
    }

    var localPath: String? {
        guard case .local(_, _, let path, _) = self else { return nil }
        return path
    }

    var localIsDirectory: Bool? {
        guard case .local(_, _, _, let isDirectory) = self else { return nil }
        return isDirectory
    }

    var isFinder: Bool {
        if case .finder = self { return true }
        return false
    }

    static let finderDefaultID = "finder:default"

    static func finderID(_ id: UUID) -> String {
        "finder:\(id.uuidString)"
    }

    static func shelfID(_ id: UUID) -> String {
        "shelf:\(id.uuidString)"
    }

    static func localID(path: String) -> String {
        "local:\(path)"
    }
}
#endif

import Foundation

/// One resolved search scope shared by source derivation and ranked content.
/// Explicit commands take precedence over the legacy session type filter.
public struct CommandSearchScope: Equatable, Sendable {
    public let intent: CommandIntent?
    public let query: String
    public let kindFilter: ShelfKindFilter

    public init(query: String, kindFilter: ShelfKindFilter) {
        intent = CommandResolver.resolve(query)
        switch intent {
        case .typeFilter(let kind, let residual):
            self.query = residual
            switch kind {
            case .file, .folder: self.kindFilter = .file
            case .text: self.kindFilter = .text
            case .url: self.kindFilter = .url
            case .application: self.kindFilter = .application
            case .action: self.kindFilter = .action
            }
        case .favorites(let residual):
            self.query = residual
            self.kindFilter = .all
        default:
            self.query = query
            self.kindFilter = kindFilter
        }
    }

    public var includesFinderQuickPaths: Bool {
        switch intent {
        case nil: return kindFilter == .all || kindFilter == .file
        case .typeFilter(let kind, _): return kind == .file || kind == .folder
        default: return false
        }
    }

    public func includes(_ item: ShelfItem) -> Bool {
        switch intent {
        case .desktopList, .desktopSwitch, .finderPath: return false
        case .favorites: return item.pinned
        case .typeFilter(let kind, _): return item.kind == kind || (kind == .file && item.kind == .folder)
        case nil: return true
        }
    }
}

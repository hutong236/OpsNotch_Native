#if os(macOS)
import Foundation
import OpsNotchCore

/// Ephemeral row data. Descriptors never load resources, execute actions, or persist state.
struct ShelfPresentationItem: Identifiable, Equatable {
    /// Preserve QuickShelfEntry navigation identity across sorting and language changes.
    typealias ID = String

    enum Icon: Equatable {
        case symbol(String)
        case file(path: String, fallbackSymbol: String)
    }

    enum Thumbnail: Equatable {
        /// A resource key for an image provider; constructing it performs no disk I/O.
        case imageFile(path: String)
    }

    enum ActionIntent: Equatable {
        case desktop(DesktopCommand)
        case openFinder(path: String, quickPathID: UUID?)
        case openLocal(path: String, isDirectory: Bool)
        case useShelfItem(UUID)
        case copyShelfItem(UUID)
        case copyPath(String)
        case revealPath(String)
        case quickLook(path: String)
        case floatingPreview(itemID: UUID)
        case setWorkingSet(itemID: UUID, included: Bool)
        case setPinned(itemID: UUID, pinned: Bool)
        case editShelfItem(UUID)
        case removeShelfItem(UUID)
    }

    struct Action: Equatable {
        let intent: ActionIntent
        let title: String
        let symbolName: String
    }

    enum Preview: Equatable {
        case unavailable
        case text(String)
        case imageFile(path: String)
        case quickLook(path: String)
    }

    enum Inspector: Equatable {
        case desktop(DesktopCommand)
        case path(String)
        case shelfItem(UUID)
    }

    let id: ID
    let icon: Icon
    let thumbnail: Thumbnail?
    let title: String
    let subtitle: String
    let metadata: [String]
    let semanticKind: SemanticKind?
    let badge: String?
    let primaryAction: Action
    /// Context menu actions; a row should expose at most two direct hover controls.
    let secondaryActions: [Action]
    let preview: Preview
    /// Quick Look remains available for image files alongside floating preview.
    let quickLookPath: String?
    let inspector: Inspector
    let accessibilityLabel: String
    let accessibilityHint: String
}
#endif

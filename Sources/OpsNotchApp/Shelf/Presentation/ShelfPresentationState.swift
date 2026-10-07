#if os(macOS)
import Foundation

enum ShelfPresentationState: Equatable, Sendable {
    case hidden
    case peek
    case expanded
    case dropTarget
    case confirmation
}
#endif

#if os(macOS)
import Foundation

@MainActor
final class ShelfPresentationCoordinator {
    private(set) var state: ShelfPresentationState = .hidden
    var onTransition: ((ShelfPresentationState) -> Void)?

    func showPeek() { transition(to: .peek) }
    func showExpanded() { transition(to: .expanded) }
    func showDropTarget() { transition(to: .dropTarget) }
    func showConfirmation() { transition(to: .confirmation) }
    func hide() { transition(to: .hidden) }

    private func transition(to next: ShelfPresentationState) {
        guard state != next else { return }
        state = next
        onTransition?(next)
    }
}
#endif

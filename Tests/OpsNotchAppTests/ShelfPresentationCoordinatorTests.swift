#if os(macOS)
import XCTest
@testable import OpsNotchApp

@MainActor
final class ShelfPresentationCoordinatorTests: XCTestCase {
    func testPresentationStatesAreExplicitAndTransitionsAreObservable() {
        let coordinator = ShelfPresentationCoordinator()
        var observed: [ShelfPresentationState] = []
        coordinator.onTransition = { observed.append($0) }

        XCTAssertEqual(coordinator.state, .hidden)

        coordinator.showPeek()
        coordinator.showExpanded()
        coordinator.showDropTarget()
        coordinator.showConfirmation()
        coordinator.hide()

        XCTAssertEqual(observed, [.peek, .expanded, .dropTarget, .confirmation, .hidden])
        XCTAssertEqual(coordinator.state, .hidden)
    }

    func testRepeatedTransitionDoesNotEmitDuplicateState() {
        let coordinator = ShelfPresentationCoordinator()
        var observed: [ShelfPresentationState] = []
        coordinator.onTransition = { observed.append($0) }

        coordinator.showExpanded()
        coordinator.showExpanded()

        XCTAssertEqual(observed, [.expanded])
    }
}
#endif

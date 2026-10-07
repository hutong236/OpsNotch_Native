#if os(macOS)
import XCTest
@testable import OpsNotchApp

final class OpsRowVisualStateTests: XCTestCase {
    func testSelectedAndFocusedCanCoexist() {
        let state = OpsRowVisualState(
            selected: true,
            focused: true,
            hovered: false,
            disabled: false,
            dragging: false
        )

        XCTAssertTrue(state.selected)
        XCTAssertTrue(state.focused)
        XCTAssertTrue(state.showsAccessories)
        XCTAssertTrue(state.showsFocusRing)
        XCTAssertEqual(state.backgroundState, .selected)
    }

    func testFocusWithoutSelectionUsesFocusedBackgroundAndRing() {
        let state = OpsRowVisualState(
            selected: false,
            focused: true,
            hovered: false,
            disabled: false,
            dragging: false
        )

        XCTAssertTrue(state.showsAccessories)
        XCTAssertTrue(state.showsFocusRing)
        XCTAssertEqual(state.backgroundState, .focused)
    }

    func testHoverShowsAccessoriesWithoutPretendingToBeKeyboardFocus() {
        let state = OpsRowVisualState(
            selected: false,
            focused: false,
            hovered: true,
            disabled: false,
            dragging: false
        )

        XCTAssertTrue(state.showsAccessories)
        XCTAssertFalse(state.showsFocusRing)
        XCTAssertEqual(state.backgroundState, .hovered)
    }

    func testDraggingKeepsStrongFocusRing() {
        let state = OpsRowVisualState(
            selected: true,
            focused: false,
            hovered: false,
            disabled: false,
            dragging: true
        )

        XCTAssertTrue(state.showsFocusRing)
        XCTAssertEqual(state.backgroundState, .dragging)
    }
}
#endif

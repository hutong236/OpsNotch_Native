#if os(macOS)
import AppKit
import XCTest
@testable import OpsNotchApp

final class ShelfKeyboardControllerTests: XCTestCase {
    func testArrowEnterAndEscapeCommandsPreserveExistingRouting() {
        XCTAssertEqual(ShelfKeyboardController.resolve(keyCode: 123, modifiers: [], firstResponderIsTextView: true), .moveLeft)
        XCTAssertEqual(ShelfKeyboardController.resolve(keyCode: 124, modifiers: [], firstResponderIsTextView: true), .moveRight)
        XCTAssertEqual(ShelfKeyboardController.resolve(keyCode: 125, modifiers: [], firstResponderIsTextView: true), .moveDown)
        XCTAssertEqual(ShelfKeyboardController.resolve(keyCode: 126, modifiers: [], firstResponderIsTextView: true), .moveUp)
        XCTAssertEqual(ShelfKeyboardController.resolve(keyCode: 36, modifiers: [], firstResponderIsTextView: true), .confirm)
        XCTAssertEqual(ShelfKeyboardController.resolve(keyCode: 76, modifiers: [], firstResponderIsTextView: true), .confirm)
        XCTAssertEqual(ShelfKeyboardController.resolve(keyCode: 53, modifiers: [], firstResponderIsTextView: true), .escape)
    }

    func testCommandShortcutsRequireCommandOnly() {
        XCTAssertEqual(ShelfKeyboardController.resolve(keyCode: 35, modifiers: [.command], firstResponderIsTextView: false), .togglePin)
        XCTAssertEqual(ShelfKeyboardController.resolve(keyCode: 2, modifiers: [.command], firstResponderIsTextView: false), .remove)
        XCTAssertNil(ShelfKeyboardController.resolve(keyCode: 35, modifiers: [.command, .shift], firstResponderIsTextView: false))
        XCTAssertNil(ShelfKeyboardController.resolve(keyCode: 2, modifiers: [.command, .option], firstResponderIsTextView: false))
    }

    func testTabIsConsumedForSearchFlowWithNoModifierOrShift() {
        XCTAssertEqual(ShelfKeyboardController.resolve(keyCode: 48, modifiers: [], firstResponderIsTextView: false), .focusSearch)
        XCTAssertEqual(ShelfKeyboardController.resolve(keyCode: 48, modifiers: [.shift], firstResponderIsTextView: true), .focusSearch)
        XCTAssertNil(ShelfKeyboardController.resolve(keyCode: 48, modifiers: [.control], firstResponderIsTextView: false))
    }

    func testSpacePreviewsOnlyOutsideTextResponder() {
        XCTAssertEqual(ShelfKeyboardController.resolve(keyCode: 49, modifiers: [], firstResponderIsTextView: false), .preview)
        XCTAssertNil(ShelfKeyboardController.resolve(keyCode: 49, modifiers: [], firstResponderIsTextView: true))
        XCTAssertNil(ShelfKeyboardController.resolve(keyCode: 49, modifiers: [.command], firstResponderIsTextView: false))
    }

    func testCapsLockFunctionAndNumericPadDoNotBreakValidShortcuts() {
        let noisy: NSEvent.ModifierFlags = [.command, .capsLock, .function, .numericPad]
        XCTAssertEqual(ShelfKeyboardController.resolve(keyCode: 35, modifiers: noisy, firstResponderIsTextView: false), .togglePin)
    }
}
#endif

import XCTest
@testable import OpsNotchCore

final class QuickShelfKeyboardNavigationTests: XCTestCase {
    func testRightTargetsFirstVisibleFinderEntry() {
        let target = QuickShelfKeyboardNavigation.destinationID(
            for: .right,
            finderEntryIDs: ["finder:default", "finder:downloads"],
            recentEntryIDs: ["shelf:newest", "shelf:older"]
        )

        XCTAssertEqual(target, "finder:default")
    }

    func testLeftTargetsFirstVisibleSmartRecentEntry() {
        let target = QuickShelfKeyboardNavigation.destinationID(
            for: .left,
            finderEntryIDs: ["finder:default"],
            recentEntryIDs: ["shelf:newest", "shelf:older"]
        )

        XCTAssertEqual(target, "shelf:newest")
    }

    func testMissingDestinationSectionReturnsNil() {
        XCTAssertNil(
            QuickShelfKeyboardNavigation.destinationID(
                for: .right,
                finderEntryIDs: [],
                recentEntryIDs: ["shelf:newest"]
            )
        )
        XCTAssertNil(
            QuickShelfKeyboardNavigation.destinationID(
                for: .left,
                finderEntryIDs: ["finder:default"],
                recentEntryIDs: []
            )
        )
    }
    func testMissingHorizontalDestinationPreservesExistingHighlightAtCallSite() {
        let currentHighlight = "shelf:current"

        let missingFinderDestination = QuickShelfKeyboardNavigation.destinationID(
            for: .right,
            finderEntryIDs: [],
            recentEntryIDs: [currentHighlight]
        )
        let highlightAfterRight = missingFinderDestination ?? currentHighlight

        let missingRecentDestination = QuickShelfKeyboardNavigation.destinationID(
            for: .left,
            finderEntryIDs: ["finder:default"],
            recentEntryIDs: []
        )
        let highlightAfterLeft = missingRecentDestination ?? currentHighlight

        XCTAssertEqual(highlightAfterRight, currentHighlight)
        XCTAssertEqual(highlightAfterLeft, currentHighlight)
    }
}

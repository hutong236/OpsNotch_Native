import XCTest
@testable import OpsNotchCore

final class QuickShelfKeyboardNavigationTests: XCTestCase {
    func testSectionBoundaryTargetsIgnoreOtherSectionOrder() {
        // Each direction enters its destination at the first rendered row,
        // even when the other section has a different length/order.
        for finderIDs in [["finder:last"], ["finder:first", "finder:last"]] {
            for recentIDs in [["shelf:last"], ["shelf:first", "shelf:last"]] {
                XCTAssertEqual(QuickShelfKeyboardNavigation.destinationID(
                    for: .right, finderEntryIDs: finderIDs, recentEntryIDs: recentIDs), finderIDs.first)
                XCTAssertEqual(QuickShelfKeyboardNavigation.destinationID(
                    for: .left, finderEntryIDs: finderIDs, recentEntryIDs: recentIDs), recentIDs.first)
            }
        }
    }

    func testBothEmptySectionsHaveNoDestinationInEitherDirection() {
        for direction in [QuickShelfHorizontalDirection.left, .right] {
            XCTAssertNil(QuickShelfKeyboardNavigation.destinationID(
                for: direction, finderEntryIDs: [], recentEntryIDs: []))
        }
    }

    func testEmptySourceSectionDoesNotBlockNonemptyDestination() {
        XCTAssertEqual(QuickShelfKeyboardNavigation.destinationID(
            for: .right, finderEntryIDs: ["finder:only"], recentEntryIDs: []), "finder:only")
        XCTAssertEqual(QuickShelfKeyboardNavigation.destinationID(
            for: .left, finderEntryIDs: [], recentEntryIDs: ["shelf:only"]), "shelf:only")
    }

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

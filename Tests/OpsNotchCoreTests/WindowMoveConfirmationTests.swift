import XCTest
@testable import OpsNotchCore

final class WindowMoveConfirmationTests: XCTestCase {
    func testTransientDualSpaceMembershipNeverConfirms() {
        var check = WindowMoveConfirmation(targetSpaceID: 93)
        for _ in 0..<5 {
            XCTAssertFalse(check.observe(spaceIDs: [3, 93], isOnTargetDisplay: true))
        }
        XCTAssertFalse(check.observe(spaceIDs: [93], isOnTargetDisplay: true))
        XCTAssertFalse(check.observe(spaceIDs: [93], isOnTargetDisplay: true))
        XCTAssertTrue(check.observe(spaceIDs: [93], isOnTargetDisplay: true))
    }

    func testIncorrectPlacementResetsConfirmationEvenWhenSpaceMatches() {
        var check = WindowMoveConfirmation(targetSpaceID: 93)
        XCTAssertFalse(check.observe(spaceIDs: [93], isOnTargetDisplay: true))
        XCTAssertFalse(check.observe(spaceIDs: [93], isOnTargetDisplay: true))
        XCTAssertFalse(check.observe(spaceIDs: [93], isOnTargetDisplay: false))
        XCTAssertFalse(check.observe(spaceIDs: [93], isOnTargetDisplay: true))
        XCTAssertFalse(check.observe(spaceIDs: [93], isOnTargetDisplay: true))
        XCTAssertTrue(check.observe(spaceIDs: [93], isOnTargetDisplay: true))
    }

    func testMissingOrRevertedMembershipResetsConfirmation() {
        var check = WindowMoveConfirmation(targetSpaceID: 93)
        XCTAssertFalse(check.observe(spaceIDs: [93], isOnTargetDisplay: true))
        XCTAssertFalse(check.observe(spaceIDs: [], isOnTargetDisplay: true))
        XCTAssertFalse(check.observe(spaceIDs: [93], isOnTargetDisplay: true))
        XCTAssertFalse(check.observe(spaceIDs: [3], isOnTargetDisplay: true))
        XCTAssertFalse(check.observe(spaceIDs: [93], isOnTargetDisplay: true))
        XCTAssertFalse(check.observe(spaceIDs: [93], isOnTargetDisplay: true))
        XCTAssertTrue(check.observe(spaceIDs: [93], isOnTargetDisplay: true))
    }
}

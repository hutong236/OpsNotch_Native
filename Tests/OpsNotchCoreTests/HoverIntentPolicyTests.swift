import XCTest
@testable import OpsNotchCore

final class HoverIntentPolicyTests: XCTestCase {
    private let policy = HoverIntentPolicy()

    func testBottomCenterEntryIsAccepted() {
        XCTAssertTrue(
            policy.acceptsEntry(
                HoverIntentPoint(x: 50, y: 2),
                activationWidth: 100,
                activationHeight: 8
            )
        )
    }

    func testHorizontalEntryFromLeftIsRejected() {
        XCTAssertFalse(
            policy.acceptsEntry(
                HoverIntentPoint(x: 1, y: 2),
                activationWidth: 100,
                activationHeight: 8
            )
        )
    }

    func testHorizontalEntryFromRightIsRejected() {
        XCTAssertFalse(
            policy.acceptsEntry(
                HoverIntentPoint(x: 99, y: 2),
                activationWidth: 100,
                activationHeight: 8
            )
        )
    }

    func testEntryTooFarInsideStripIsRejected() {
        XCTAssertFalse(
            policy.acceptsEntry(
                HoverIntentPoint(x: 50, y: 7),
                activationWidth: 100,
                activationHeight: 8
            )
        )
    }

    func testSmallMovementRemainsStable() {
        XCTAssertTrue(
            policy.remainsStable(
                from: HoverIntentPoint(x: 50, y: 2),
                to: HoverIntentPoint(x: 53, y: 6)
            )
        )
    }

    func testMovementPastThresholdCancelsIntent() {
        XCTAssertFalse(
            policy.remainsStable(
                from: HoverIntentPoint(x: 50, y: 2),
                to: HoverIntentPoint(x: 57, y: 2)
            )
        )
    }
}

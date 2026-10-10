import XCTest
@testable import OpsNotchCore

final class ClipboardCaptureQueueBudgetTests: XCTestCase {
    func testEmptyQueueAcceptsSingleLargePasteboardSnapshot() {
        // A very large screenshot must not be silently blocked forever.
        XCTAssertTrue(ClipboardCaptureQueueBudget.shouldReadNextChange(
            outstandingItemCount: 0,
            outstandingByteCount: 0
        ))
        XCTAssertTrue(ClipboardCaptureQueueBudget.shouldReadNextChange(
            outstandingItemCount: 0,
            outstandingByteCount: ClipboardCaptureQueueBudget.maximumBufferedBytes * 2
        ))
    }

    func testByteBudgetDefersAdditionalPayloadReads() {
        let cap = ClipboardCaptureQueueBudget.maximumBufferedBytes
        XCTAssertTrue(ClipboardCaptureQueueBudget.shouldReadNextChange(
            outstandingItemCount: 1, outstandingByteCount: cap - 1
        ))
        XCTAssertFalse(ClipboardCaptureQueueBudget.shouldReadNextChange(
            outstandingItemCount: 1, outstandingByteCount: cap
        ))
        XCTAssertFalse(ClipboardCaptureQueueBudget.shouldReadNextChange(
            outstandingItemCount: 1, outstandingByteCount: cap + 1
        ))
    }

    func testItemCountBudgetHandlesManySmallClipboardChanges() {
        let cap = ClipboardCaptureQueueBudget.maximumOutstandingItems
        XCTAssertGreaterThanOrEqual(cap, 20, "Rapid text copy acceptance must retain its baseline")
        XCTAssertTrue(ClipboardCaptureQueueBudget.shouldReadNextChange(
            outstandingItemCount: cap - 1, outstandingByteCount: 10
        ))
        XCTAssertFalse(ClipboardCaptureQueueBudget.shouldReadNextChange(
            outstandingItemCount: cap, outstandingByteCount: 10
        ))
    }

    func testCapacityReturnsAfterWorkerFinishes() {
        let cap = ClipboardCaptureQueueBudget.maximumBufferedBytes
        XCTAssertFalse(ClipboardCaptureQueueBudget.shouldReadNextChange(
            outstandingItemCount: 3, outstandingByteCount: cap
        ))
        XCTAssertTrue(ClipboardCaptureQueueBudget.shouldReadNextChange(
            outstandingItemCount: 2, outstandingByteCount: cap / 2
        ))
    }
}

import XCTest
@testable import OpsNotchCore

final class ClipboardPollingPolicyTests: XCTestCase {
    func testHiddenShelfKeepsExistingCaptureCadenceButAddsTimerTolerance() {
        let schedule = ClipboardPollingPolicy.schedule(panelVisible: false)

        XCTAssertEqual(schedule.intervalMilliseconds, 400)
        XCTAssertEqual(schedule.toleranceMilliseconds, 100)
    }

    func testVisibleShelfKeepsFastCaptureCadenceWithSmallTolerance() {
        let schedule = ClipboardPollingPolicy.schedule(panelVisible: true)

        XCTAssertEqual(schedule.intervalMilliseconds, 100)
        XCTAssertEqual(schedule.toleranceMilliseconds, 20)
    }
}

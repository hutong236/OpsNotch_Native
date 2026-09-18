import XCTest
@testable import OpsNotchCore

final class SensorMouseEventPolicyTests: XCTestCase {
    func testIdleSensorPassesOrdinaryMouseEventsThrough() {
        XCTAssertTrue(
            SensorMouseEventPolicy.ignoresMouseEvents(externalDragSessionActive: false)
        )
    }

    func testRecognizedExternalDragEnablesSensorHitTesting() {
        XCTAssertFalse(
            SensorMouseEventPolicy.ignoresMouseEvents(externalDragSessionActive: true)
        )
    }

    func testDragLifecycleRestoresPassthroughAfterSessionEnds() {
        let states = [false, true, false]
        let ignoresMouseEvents = states.map {
            SensorMouseEventPolicy.ignoresMouseEvents(externalDragSessionActive: $0)
        }

        XCTAssertEqual(ignoresMouseEvents, [true, false, true])
    }
}

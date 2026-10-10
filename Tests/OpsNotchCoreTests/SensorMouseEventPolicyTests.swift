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

    func testIdleSensorPanelVisibilityTracksRecognizedDragLifecycle() {
        let sessionStates = [false, true, false]
        let panelVisibility = sessionStates.map {
            SensorMouseEventPolicy.shouldPresentSensorPanel(externalDragSessionActive: $0)
        }
        XCTAssertEqual(panelVisibility, [false, true, false])
    }

    // Idle operation must not require a process-wide mouse-up wakeup.
    func testGlobalMouseUpMonitorOnlyRunsDuringExternalDragSession() {
        XCTAssertFalse(
            SensorMouseEventPolicy.shouldMonitorGlobalMouseUp(externalDragSessionActive: false)
        )
        XCTAssertTrue(
            SensorMouseEventPolicy.shouldMonitorGlobalMouseUp(externalDragSessionActive: true)
        )
    }
}

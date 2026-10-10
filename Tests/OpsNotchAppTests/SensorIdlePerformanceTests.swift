#if os(macOS)
import AppKit
import XCTest
@testable import OpsNotchApp

final class SensorIdlePerformanceTests: XCTestCase {
    @MainActor
    func testSensorHasNoAlwaysActivePointerTrackingArea() {
        let sensor = SensorView(frame: NSRect(x: 0, y: 0, width: 360, height: 62))

        // Native NSDraggingDestination registration is independent of pointer
        // tracking. Hidden idle sensors must not register tracking areas.
        sensor.updateTrackingAreas()
        XCTAssertFalse(sensor.trackingAreas.contains { $0.owner === sensor })
    }
}
#endif

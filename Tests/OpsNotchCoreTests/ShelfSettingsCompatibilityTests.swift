import XCTest
@testable import OpsNotchCore

final class ShelfSettingsCompatibilityTests: XCTestCase {
    func testDragAssistDefaultsToNearby() {
        XCTAssertEqual(ShelfSettings().dragAssistMode, .nearby)
    }

    func testLegacySettingsWithoutDragAssistModeDecodeAsNearby() throws {
        let json = """
        {
          "temp_ttl_hours": 24,
          "add_mode": "reference",
          "display_target": "all",
          "language": "zh-CN",
          "finder_reveal_app_name": "gf.app",
          "finder_default_path": "~",
          "finder_quick_paths": [],
          "working_set_item_ids": [],
          "shelf_keep_open": false
        }
        """

        let decoded = try JSONDecoder().decode(ShelfSettings.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.dragAssistMode, .nearby)
    }

    func testSensorOnlyRoundTripsThroughCodable() throws {
        var settings = ShelfSettings()
        settings.dragAssistMode = .sensorOnly

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ShelfSettings.self, from: data)

        XCTAssertEqual(decoded.dragAssistMode, .sensorOnly)
    }
}

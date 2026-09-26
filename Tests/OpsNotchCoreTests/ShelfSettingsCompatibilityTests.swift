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

    func testLegacyMenuBarFieldsAreIgnoredAfterFeatureRemoval() throws {
        let json = """
        {
          "menu_bar_management_enabled": true,
          "menu_bar_auto_hide_seconds": 10,
          "menu_bar_start_collapsed": false,
          "menu_bar_always_hidden_enabled": true,
          "menu_bar_panel_enabled": true,
          "menu_bar_animation_enabled": false,
          "menu_bar_last_state": "all_expanded"
        }
        """

        let decoded = try JSONDecoder().decode(ShelfSettings.self, from: Data(json.utf8))
        let encoded = try JSONEncoder().encode(decoded)
        let encodedJSON = String(decoding: encoded, as: UTF8.self)

        XCTAssertFalse(encodedJSON.contains("menu_bar_"))
    }
}

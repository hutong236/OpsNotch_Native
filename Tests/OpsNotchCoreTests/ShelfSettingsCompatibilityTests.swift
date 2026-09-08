import XCTest
@testable import OpsNotchCore

final class ShelfSettingsCompatibilityTests: XCTestCase {
    func testDragAssistDefaultsToNearby() {
        XCTAssertEqual(ShelfSettings().dragAssistMode, .nearby)
    }

    func testMenuBarManagerDefaultsAreBackwardSafe() {
        let settings = ShelfSettings()
        XCTAssertFalse(settings.menuBarManagementEnabled)
        XCTAssertEqual(settings.menuBarAutoHideSeconds, 30)
        XCTAssertTrue(settings.menuBarStartCollapsed)
        XCTAssertFalse(settings.menuBarAlwaysHiddenEnabled)
        XCTAssertNil(settings.menuBarHotkey)
        XCTAssertFalse(settings.menuBarPanelEnabled)
        XCTAssertTrue(settings.menuBarAnimationEnabled)
        XCTAssertEqual(settings.menuBarLastState, .hiddenExpanded)
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
        XCTAssertFalse(decoded.menuBarManagementEnabled)
        XCTAssertEqual(decoded.menuBarAutoHideSeconds, 30)
        XCTAssertTrue(decoded.menuBarStartCollapsed)
        XCTAssertFalse(decoded.menuBarAlwaysHiddenEnabled)
        XCTAssertFalse(decoded.menuBarPanelEnabled)
        XCTAssertTrue(decoded.menuBarAnimationEnabled)
        XCTAssertEqual(decoded.menuBarLastState, .hiddenExpanded)
    }

    func testSensorOnlyRoundTripsThroughCodable() throws {
        var settings = ShelfSettings()
        settings.dragAssistMode = .sensorOnly

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ShelfSettings.self, from: data)

        XCTAssertEqual(decoded.dragAssistMode, .sensorOnly)
    }

    func testMenuBarSettingsRoundTripThroughCodable() throws {
        var settings = ShelfSettings()
        settings.menuBarManagementEnabled = true
        settings.menuBarAutoHideSeconds = 10
        settings.menuBarStartCollapsed = false
        settings.menuBarAlwaysHiddenEnabled = true
        settings.menuBarHotkey = HotkeyShortcut(keyCode: 46, carbonModifiers: HotkeyValidation.carbonCommand)
        settings.menuBarPanelEnabled = true
        settings.menuBarAnimationEnabled = false
        settings.menuBarLastState = .allExpanded

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ShelfSettings.self, from: data)

        XCTAssertTrue(decoded.menuBarManagementEnabled)
        XCTAssertEqual(decoded.menuBarAutoHideSeconds, 10)
        XCTAssertFalse(decoded.menuBarStartCollapsed)
        XCTAssertTrue(decoded.menuBarAlwaysHiddenEnabled)
        XCTAssertEqual(decoded.menuBarHotkey, settings.menuBarHotkey)
        XCTAssertTrue(decoded.menuBarPanelEnabled)
        XCTAssertFalse(decoded.menuBarAnimationEnabled)
        XCTAssertEqual(decoded.menuBarLastState, .allExpanded)
    }
}

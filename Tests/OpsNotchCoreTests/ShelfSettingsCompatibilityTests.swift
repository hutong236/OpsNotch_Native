import XCTest
@testable import OpsNotchCore

final class ShelfSettingsCompatibilityTests: XCTestCase {
    func testSupportedSettingsSurviveUnrelatedUISettingUpdate() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)
        var settings = ShelfSettings()
        settings.tempTTLHours = 96
        settings.addMode = .copy
        settings.displayTarget = .mouse
        settings.dragAssistMode = .sensorOnly
        settings.language = .enUS
        settings.hotkey = HotkeyShortcut(keyCode: 12, carbonModifiers: 256)
        settings.finderRevealAppName = "Finder.app"
        settings.finderRevealHotkey = HotkeyShortcut(keyCode: 13, carbonModifiers: 512)
        settings.finderDefaultPath = "~/Documents"
        settings.finderQuickPaths = [FinderQuickPath(label: "Projects", path: "~/Projects", useCount: 17, lastUsedAt: 900)]
        let stored = try service.addText("Keep this working item")
        settings.workingSetItemIDs = stored.items.map(\.id)
        _ = try service.updateSettings(settings)
        settings.shelfKeepOpen = true
        _ = try service.updateSettings(settings)
        XCTAssertEqual(try service.load().settings, settings)
    }

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

    func testLegacyMenuBarFieldsAreRemovedFromPersistedStoreDuringMigration() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-menu-bar-removal-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let json = """
        {
          "version": 24,
          "items": [],
          "settings": {
            "temp_ttl_hours": 24,
            "add_mode": "reference",
            "display_target": "all",
            "language": "zh-CN",
            "menu_bar_management_enabled": true,
            "menu_bar_auto_hide_seconds": 10,
            "menu_bar_start_collapsed": false,
            "menu_bar_always_hidden_enabled": true,
            "menu_bar_panel_enabled": true,
            "menu_bar_animation_enabled": false,
            "menu_bar_last_state": "all_expanded"
          }
        }
        """
        let storeURL = root.appendingPathComponent("shelf.json")
        try Data(json.utf8).write(to: storeURL)

        let service = ShelfStoreService(rootURL: root)
        let loaded = try service.load()
        let rewritten = try String(contentsOf: storeURL, encoding: .utf8)

        XCTAssertEqual(loaded.version, ShelfStore.currentVersion)
        XCTAssertEqual(ShelfStore.currentVersion, 25)
        XCTAssertFalse(rewritten.contains("menu_bar_"))
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
    func testLegacyV28SettingsDecodeWithStableDefaultsAndRoundTrip() throws {
        let json = """
        {
          "temp_ttl_hours": 72,
          "add_mode": "copy",
          "display_target": "mouse",
          "language": "en-US",
          "finder_reveal_app_name": "gf.app",
          "finder_default_path": "~/Downloads",
          "finder_quick_paths": [],
          "working_set_item_ids": [],
          "shelf_keep_open": true
        }
        """

        let decoded = try JSONDecoder().decode(ShelfSettings.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.tempTTLHours, 72)
        XCTAssertEqual(decoded.addMode, .copy)
        XCTAssertEqual(decoded.displayTarget, .mouse)
        XCTAssertEqual(decoded.dragAssistMode, .nearby)
        XCTAssertEqual(decoded.language, .enUS)
        XCTAssertNil(decoded.hotkey)
        XCTAssertNil(decoded.finderRevealHotkey)
        XCTAssertEqual(decoded.finderDefaultPath, "~/Downloads")
        XCTAssertTrue(decoded.finderQuickPaths.isEmpty)
        XCTAssertTrue(decoded.workingSetItemIDs.isEmpty)
        XCTAssertTrue(decoded.shelfKeepOpen)

        let roundTripped = try JSONDecoder().decode(
            ShelfSettings.self,
            from: JSONEncoder().encode(decoded)
        )
        XCTAssertEqual(roundTripped, decoded)
    }
    func testThreePointOhSettingsNavigationPreservesPersistedFieldSet() throws {
        var settings = ShelfSettings()
        settings.tempTTLHours = 168
        settings.addMode = .copy
        settings.displayTarget = .primary
        settings.dragAssistMode = .sensorOnly
        settings.language = .enUS
        settings.hotkey = HotkeyShortcut(keyCode: 31, carbonModifiers: 768)
        settings.finderRevealHotkey = HotkeyShortcut(keyCode: 3, carbonModifiers: 256)
        settings.finderDefaultPath = "~/Projects"
        settings.finderQuickPaths = [FinderQuickPath(label: "Ops", path: "~/Projects/Ops")]
        settings.workingSetItemIDs = [UUID()]
        settings.shelfKeepOpen = true

        let data = try JSONEncoder().encode(settings)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(
            Set(object.keys),
            Set([
                "temp_ttl_hours", "add_mode", "display_target", "drag_assist_mode",
                "language", "hotkey", "finder_reveal_app_name", "finder_reveal_hotkey",
                "finder_default_path", "finder_quick_paths", "working_set_item_ids",
                "shelf_keep_open"
            ])
        )

        let decoded = try JSONDecoder().decode(ShelfSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }

}

#if os(macOS)
import AppKit
import XCTest
@testable import OpsNotchApp

@MainActor
final class SettingsWindowPresentationTests: XCTestCase {
    func testVisibleWindowDoesNotNeedRecentering() {
        let screens = [NSRect(x: 0, y: 0, width: 1440, height: 900)]
        let window = NSRect(x: 300, y: 180, width: 840, height: 620)

        XCTAssertFalse(SettingsWindowVisibilityPolicy.needsRecentering(windowFrame: window, visibleFrames: screens))
    }

    func testOffscreenWindowNeedsRecentering() {
        let screens = [NSRect(x: 0, y: 0, width: 1440, height: 900)]
        let window = NSRect(x: 1800, y: 100, width: 840, height: 620)

        XCTAssertTrue(SettingsWindowVisibilityPolicy.needsRecentering(windowFrame: window, visibleFrames: screens))
    }

    func testSmallVisibleSliverStillRecenters() {
        let screens = [NSRect(x: 0, y: 0, width: 1440, height: 900)]
        let window = NSRect(x: 1410, y: 100, width: 840, height: 620)

        XCTAssertTrue(SettingsWindowVisibilityPolicy.needsRecentering(windowFrame: window, visibleFrames: screens))
    }

    func testMeaningfulIntersectionOnSecondaryDisplayStaysPut() {
        let screens = [
            NSRect(x: 0, y: 0, width: 1440, height: 900),
            NSRect(x: 1440, y: 0, width: 1920, height: 1080)
        ]
        let window = NSRect(x: 1700, y: 200, width: 840, height: 620)

        XCTAssertFalse(SettingsWindowVisibilityPolicy.needsRecentering(windowFrame: window, visibleFrames: screens))
    }
}
#endif

#if os(macOS)
import AppKit
import XCTest
import OpsNotchCore
@testable import OpsNotchApp

final class NearbyDropViewTests: XCTestCase {
    @MainActor
    func testChineseIdleReadyAndResetStates() {
        let view = NearbyDropView(frame: NSRect(x: 0, y: 0, width: 336, height: 116))
        view.apply(language: .zhCN)

        XCTAssertEqual(view.accessibilityLabel(), "拖到这里暂存")
        XCTAssertEqual(view.accessibilityHelp(), "文件 · 文件夹 · 链接 · 文字")
        XCTAssertEqual(view.layer?.borderWidth, 1)

        view.setReady(true)
        XCTAssertEqual(view.accessibilityLabel(), "松开即可放入")
        XCTAssertEqual(view.layer?.borderWidth, 1.5)

        view.resetVisualState()
        XCTAssertEqual(view.accessibilityLabel(), "拖到这里暂存")
        XCTAssertEqual(view.layer?.borderWidth, 1)
    }

    @MainActor
    func testFilePromiseProgressStopsBlockingPointerWithoutHidingProgress() throws {
        guard let screen = NSScreen.screens.first else {
            throw XCTSkip("Requires a macOS display to present the native overlay")
        }

        let overlay = DragDropOverlayController()
        XCTAssertTrue(overlay.isPointerPassthrough, "Idle nearby panel must be click-through")

        overlay.show(near: NSPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.midY),
                     on: screen, language: .zhCN)
        XCTAssertTrue(overlay.isVisible)
        XCTAssertFalse(overlay.isPointerPassthrough, "Active drag needs an accepting drop target")

        overlay.beginPromiseResolution()
        XCTAssertTrue(overlay.isVisible, "Progress must remain visible while files arrive")
        XCTAssertTrue(overlay.isPointerPassthrough, "Receiving must not block other app clicks")

        overlay.hide()
        XCTAssertTrue(overlay.isPointerPassthrough)
        overlay.show(near: NSPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.midY),
                     on: screen, language: .enUS)
        XCTAssertFalse(overlay.isPointerPassthrough, "Next drag must re-enable drop hit testing")
        overlay.hide()
    }

    @MainActor
    func testEnglishCopyUpdatesWithoutRebuildingTheView() {
        let view = NearbyDropView(frame: NSRect(x: 0, y: 0, width: 336, height: 116))
        view.apply(language: .enUS)
        XCTAssertEqual(view.accessibilityLabel(), "Drag here to save")
        XCTAssertEqual(view.accessibilityHelp(), "Files · Folders · Links · Text")

        view.setReady(true)
        XCTAssertEqual(view.accessibilityLabel(), "Release to add")
        XCTAssertEqual(view.accessibilityHelp(), "Files · Folders · Links · Text")

        view.apply(language: .zhCN)
        XCTAssertEqual(view.accessibilityLabel(), "拖到这里暂存")
    }
}
#endif

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

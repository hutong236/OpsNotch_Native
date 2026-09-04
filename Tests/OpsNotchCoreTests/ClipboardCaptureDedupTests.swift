import XCTest
@testable import OpsNotchCore

final class ClipboardCaptureDedupTests: XCTestCase {
    func testClipboardCaptureReusesExistingTextItem() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)

        let first = try service.captureText("same text")
        let firstID = try XCTUnwrap(first.items.first?.id)
        let second = try service.captureText("same text")

        XCTAssertEqual(second.items.count, 1)
        XCTAssertEqual(second.items.first?.id, firstID)
        XCTAssertEqual(second.items.first?.content, "same text")
    }

    func testClipboardCaptureNormalizesWhitespaceAndLineEndingsForDedup() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)

        let first = try service.captureText("line 1\nline 2")
        let firstID = try XCTUnwrap(first.items.first?.id)
        let second = try service.captureText("  line 1\r\nline 2  \n")

        XCTAssertEqual(second.items.count, 1)
        XCTAssertEqual(second.items.first?.id, firstID)
        XCTAssertEqual(second.items.first?.content, "line 1\nline 2")
    }

    func testManualAddTextStillAllowsDuplicateContent() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)

        _ = try service.addText("same text", title: "First")
        let store = try service.addText("same text", title: "Second")

        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(Set(store.items.map(\.title)), Set(["First", "Second"]))
    }

    func testClipboardCaptureReusesTextCreatedManually() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)

        let manual = try service.addText("existing", title: "Custom title")
        let manualID = try XCTUnwrap(manual.items.first?.id)
        let captured = try service.captureText("existing")

        XCTAssertEqual(captured.items.count, 1)
        XCTAssertEqual(captured.items.first?.id, manualID)
        XCTAssertEqual(captured.items.first?.title, "Custom title")
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-clipboard-dedup-tests-\(UUID().uuidString)", isDirectory: true)
    }
}

#if os(macOS)
import AppKit
import XCTest
import OpsNotchCore
@testable import OpsNotchApp

final class ClipboardImageRecopyTests: XCTestCase {
    @MainActor
    func testImageRecopyPublishesPNGWithoutReencodingOrRecapture() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let png = Data([137, 80, 78, 71, 13, 10, 26, 10, 3, 7])
        let file = root.appendingPathComponent("image.png")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try png.write(to: file)
        let board = makePasteboard()
        let manager = ClipboardManager(
            model: AppModel(store: ShelfStoreService(rootURL: root)),
            pasteboard: board
        )

        let completed = expectation(description: "image read and pasteboard publication")
        manager.copyImageFile(file.path) { success in
            XCTAssertTrue(success)
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 10)

        XCTAssertEqual(board.data(forType: NSPasteboard.PasteboardType("public.png")), png)
        XCTAssertFalse(manager.catchIfChanged(), "Own image copy must not reenter Recent")
    }

    @MainActor
    func testSlowImageNeverOverwritesNewerTextCopy() async {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let board = makePasteboard()
        let manager = ClipboardManager(
            model: AppModel(store: ShelfStoreService(rootURL: root)),
            pasteboard: board,
            imageFileLoader: { _ in Data([1, 2, 3]) }
        )

        let completed = expectation(description: "superseded read")
        manager.copyImageFile("older-image") { success in
            XCTAssertFalse(success)
            completed.fulfill()
        }
        manager.copyFromApp("newer text")
        await fulfillment(of: [completed], timeout: 10)

        XCTAssertEqual(board.string(forType: .string), "newer text")
        XCTAssertNil(board.data(forType: NSPasteboard.PasteboardType("public.png")))
    }

    @MainActor
    func testLaterImageRequestWinsOverEarlierRequest() async {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let board = makePasteboard()
        let manager = ClipboardManager(
            model: AppModel(store: ShelfStoreService(rootURL: root)),
            pasteboard: board,
            imageFileLoader: { path in
                path == "newer-image" ? Data([7, 8, 9]) : Data([1, 2, 3])
            }
        )

        let first = expectation(description: "outdated request completes")
        let second = expectation(description: "latest request completes")
        manager.copyImageFile("older-image") { success in
            XCTAssertFalse(success)
            first.fulfill()
        }
        manager.copyImageFile("newer-image") { success in
            XCTAssertTrue(success)
            second.fulfill()
        }
        await fulfillment(of: [first, second], timeout: 10)

        XCTAssertEqual(board.data(forType: NSPasteboard.PasteboardType("public.png")), Data([7, 8, 9]))
    }

    @MainActor
    func testMissingImageDoesNotClearExistingClipboard() async {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let board = makePasteboard()
        board.setString("preserve me", forType: .string)
        let manager = ClipboardManager(
            model: AppModel(store: ShelfStoreService(rootURL: root)),
            pasteboard: board
        )

        let completed = expectation(description: "missing image finishes")
        manager.copyImageFile(root.appendingPathComponent("missing.png").path) { success in
            XCTAssertFalse(success)
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 10)

        XCTAssertEqual(board.string(forType: .string), "preserve me")
    }

    private func makePasteboard() -> NSPasteboard {
        let board = NSPasteboard(name: NSPasteboard.Name("lab.hutong.opsnotch.test.\(UUID())"))
        board.clearContents()
        return board
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-image-recopy-\(UUID().uuidString)", isDirectory: true)
    }
}
#endif

import XCTest
@testable import OpsNotchCore

final class ClipboardExperienceTests: XCTestCase {
    func testCapturedTextStoresAndRefreshesSourceApp() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)

        let first = try service.captureText("kubectl get pods", sourceAppName: "Terminal")
        let id = try XCTUnwrap(first.items.first?.id)
        XCTAssertEqual(first.items.first?.sourceAppName, "Terminal")

        let second = try service.captureText("kubectl get pods", sourceAppName: "iTerm")
        XCTAssertEqual(second.items.count, 1)
        XCTAssertEqual(second.items.first?.id, id)
        XCTAssertEqual(second.items.first?.sourceAppName, "iTerm")
    }

    func testClipboardImageCapturePersistsManagedImageMetadata() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)
        let bytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])

        let store = try service.captureImageData(bytes, sourceAppName: "Preview")
        let item = try XCTUnwrap(store.items.first)

        XCTAssertEqual(item.kind, .file)
        XCTAssertEqual(item.storageMode, .copy)
        XCTAssertEqual(item.fileExtension, "png")
        XCTAssertEqual(item.sourceAppName, "Preview")
        XCTAssertTrue(item.clipboardImage)
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.content))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: item.content)), bytes)
    }

    func testIdenticalImageCaptureReusesManagedFileAndPreservesPin() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)
        let original = Data([137, 80, 78, 71, 10, 20, 30])

        let first = try service.captureImageData(original, sourceAppName: "Preview")
        let image = try XCTUnwrap(first.items.first)
        _ = try service.setPinned(id: image.id, pinned: true)
        let second = try service.captureImageData(original, sourceAppName: "Photos")

        XCTAssertEqual(second.items.count, 1)
        XCTAssertEqual(second.items.first?.id, image.id)
        XCTAssertEqual(second.items.first?.content, image.content)
        XCTAssertEqual(second.items.first?.pinned, true)
        XCTAssertEqual(second.items.first?.sourceAppName, "Photos")
        XCTAssertTrue(FileManager.default.fileExists(atPath: image.content))

        let folders = try FileManager.default.contentsOfDirectory(
            at: service.managedFilesURL, includingPropertiesForKeys: nil
        )
        XCTAssertEqual(folders.count, 1, "Recopying should not allocate a second managed file")
    }

    func testImageDedupFindsRecentMatchBetweenDifferentImages() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)
        let original = Data([1, 2, 3, 4])
        let first = try service.captureImageData(original)
        let firstID = try XCTUnwrap(first.items.first?.id)

        _ = try service.captureImageData(Data([5, 6, 7, 8]))
        let third = try service.captureImageData(original)

        XCTAssertEqual(third.items.count, 2)
        XCTAssertEqual(third.items.filter { $0.id == firstID }.count, 1)
        XCTAssertEqual(third.items.first(where: { $0.id == firstID })?.clipboardImage, true)
    }

    func testImageDedupDoesNotReuseMissingManagedFile() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)
        let bytes = Data([10, 11, 12, 13])
        let first = try service.captureImageData(bytes)
        let storedFile = try XCTUnwrap(first.items.first?.content)
        try FileManager.default.removeItem(atPath: storedFile)

        let second = try service.captureImageData(bytes)
        XCTAssertEqual(second.items.count, 2)
        XCTAssertNotEqual(second.items[0].id, second.items[1].id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.items[1].content))
    }

    func testRemovingClipboardImageRemovesManagedStorage() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)

        let store = try service.captureImageData(Data([1, 2, 3]), sourceAppName: "Preview")
        let item = try XCTUnwrap(store.items.first)
        let managedParent = URL(fileURLWithPath: item.content).deletingLastPathComponent()
        XCTAssertTrue(FileManager.default.fileExists(atPath: managedParent.path))

        _ = try service.remove(ids: [item.id])
        XCTAssertFalse(FileManager.default.fileExists(atPath: managedParent.path))
    }

    func testLegacyShelfItemDecodesClipboardMetadataDefaults() throws {
        let id = UUID()
        let json = """
        {
          "id":"\(id.uuidString)",
          "kind":"text",
          "title":"legacy",
          "content":"value",
          "pinned":false,
          "created_at":1,
          "updated_at":1
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(ShelfItem.self, from: json)
        XCTAssertNil(item.sourceAppName)
        XCTAssertFalse(item.clipboardImage)
    }

    func testSearchMatchesSourceApplication() {
        let item = ShelfItem(
            kind: .text,
            title: "cluster command",
            content: "kubectl get pods",
            sourceAppName: "Terminal"
        )

        XCTAssertTrue(ShelfLogic.matches(item, query: "terminal"))
        XCTAssertFalse(ShelfLogic.matches(item, query: "safari"))
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-clipboard-experience-tests-\(UUID().uuidString)", isDirectory: true)
    }
}

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

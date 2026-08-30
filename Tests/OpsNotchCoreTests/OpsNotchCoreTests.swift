import XCTest
@testable import OpsNotchCore

final class OpsNotchCoreTests: XCTestCase {
    func testLegacyTextKindsDecodeAsText() throws {
        let json = #"{"id":"00000000-0000-0000-0000-000000000001","kind":"ip","title":"IP","content":"192.168.0.1","pinned":false,"created_at":1,"updated_at":1}"#.data(using: .utf8)!
        let item = try JSONDecoder().decode(ShelfItem.self, from: json)
        XCTAssertEqual(item.kind, .text)
    }

    func testLegacyArrayStoreLoads() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let now = ShelfClock.now()
        let json = "[{\"id\":\"00000000-0000-0000-0000-000000000002\",\"kind\":\"command\",\"title\":\"cmd\",\"content\":\"ls -la\",\"pinned\":false,\"created_at\":\(now),\"updated_at\":\(now)}]"
        try json.data(using: .utf8)!.write(to: root.appendingPathComponent("shelf.json"))
        let service = ShelfStoreService(rootURL: root)
        let store = try service.load()
        XCTAssertEqual(store.version, ShelfStore.currentVersion)
        XCTAssertEqual(store.items.first?.kind, .text)
    }

    func testPinnedOrdersBeforeRecent() {
        let a = ShelfItem(kind: .text, title: "Recent", content: "A", pinned: false, createdAt: 20, updatedAt: 20)
        let b = ShelfItem(kind: .text, title: "Pinned", content: "B", pinned: true, createdAt: 10, updatedAt: 10)
        XCTAssertEqual(ShelfLogic.ordered([a, b]).map(\.title), ["Pinned", "Recent"])
    }

    func testSearchMatchesContent() {
        let item = ShelfItem(kind: .text, title: "Server", content: "192.168.0.205")
        XCTAssertTrue(ShelfLogic.matches(item, query: "0.205"))
        XCTAssertFalse(ShelfLogic.matches(item, query: "database"))
    }

    func testTTLDoesNotExpirePinnedItems() {
        let now: UInt64 = 10_000
        let old = ShelfItem(kind: .text, title: "Old", content: "x", pinned: false, createdAt: 1, updatedAt: 1)
        let pinned = ShelfItem(kind: .text, title: "Pinned", content: "x", pinned: true, createdAt: 1, updatedAt: 1)
        let settings = ShelfSettings(tempTTLHours: 1)
        let expired = ShelfLogic.expiredIDs(items: [old, pinned], settings: settings, now: now)
        XCTAssertTrue(expired.contains(old.id))
        XCTAssertFalse(expired.contains(pinned.id))
    }

    func testUnpinPersistsAndReturnsToRecent() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)
        let added = try service.addText("pin me")
        let id = try XCTUnwrap(added.items.first?.id)

        _ = try service.setPinned(id: id, pinned: true)
        let afterPin = try service.load()
        XCTAssertEqual(afterPin.items.first?.pinned, true)
        XCTAssertEqual(ShelfLogic.grouped(afterPin.items).pinned.map(\.id), [id])

        _ = try service.setPinned(id: id, pinned: false)
        let afterUnpin = try service.load()
        XCTAssertEqual(afterUnpin.items.first?.pinned, false)
        XCTAssertEqual(ShelfLogic.grouped(afterUnpin.items).recent.map(\.id), [id])
    }

    func testUnpinnedItemBecomesEligibleForTTLExpiry() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)
        let added = try service.addText("temp")
        let id = try XCTUnwrap(added.items.first?.id)

        _ = try service.setPinned(id: id, pinned: true)
        _ = try service.setPinned(id: id, pinned: false)

        let store = try service.load()
        let item = try XCTUnwrap(store.items.first)
        XCTAssertFalse(item.pinned)
        let settings = ShelfSettings(tempTTLHours: 1)
        let beforeTTL = ShelfLogic.expiredIDs(items: store.items, settings: settings, now: item.updatedAt + 3599)
        XCTAssertFalse(beforeTTL.contains(id))
        let afterTTL = ShelfLogic.expiredIDs(items: store.items, settings: settings, now: item.updatedAt + 3600)
        XCTAssertTrue(afterTTL.contains(id))
    }

    func testReferenceRemovalNeverDeletesOriginal() throws {
        let root = temporaryRoot()
        let original = root.appendingPathComponent("outside.txt")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: original)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = ShelfStoreService(rootURL: root.appendingPathComponent("store"))
        let store = try service.addPath(original, mode: .reference)
        let id = try XCTUnwrap(store.items.first?.id)
        _ = try service.remove(ids: [id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
    }

    func testCopyInUsesManagedDirectoryAndDeletesItOnRemove() throws {
        let root = temporaryRoot()
        let original = root.appendingPathComponent("outside.txt")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: original)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = ShelfStoreService(rootURL: root.appendingPathComponent("store"))
        let store = try service.addPath(original, mode: .copy)
        let item = try XCTUnwrap(store.items.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.content))
        _ = try service.remove(ids: [item.id])
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.content))
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
    }

    func testSafeActionRejectsShellCommand() {
        XCTAssertTrue(SafeActionValidator.validate(kind: .openURL, content: "https://example.com"))
        XCTAssertTrue(SafeActionValidator.validate(kind: .openPath, content: "/Applications/Terminal.app"))
        XCTAssertFalse(SafeActionValidator.validate(kind: .openPath, content: "rm -rf /"))
        XCTAssertFalse(SafeActionValidator.validate(kind: .openURL, content: "javascript:alert(1)"))
    }

    func testPreviewKindDetectsImageExtensions() {
        XCTAssertTrue(ItemPreviewKind.isImagePath("/tmp/photo.JPG"))
        XCTAssertTrue(ItemPreviewKind.isImagePath("/tmp/photo.heic"))
        XCTAssertTrue(ItemPreviewKind.isImagePath("/tmp/diagram.WebP"))
        XCTAssertFalse(ItemPreviewKind.isImagePath("/tmp/report.pdf"))
        XCTAssertFalse(ItemPreviewKind.isImagePath("/tmp/noextension"))
        XCTAssertFalse(ItemPreviewKind.isImagePath(""))
    }

    func testPreviewKindItemEligibility() {
        XCTAssertTrue(ItemPreviewKind.isPreviewable(ShelfItem(kind: .text, title: "T", content: "hello")))
        XCTAssertFalse(ItemPreviewKind.isPreviewable(ShelfItem(kind: .text, title: "T", content: "")))
        XCTAssertTrue(ItemPreviewKind.isPreviewable(ShelfItem(kind: .file, title: "Img", content: "/tmp/a.png")))
        // 引用模式下 content 是路径,extension 兜底同样可识别
        XCTAssertTrue(ItemPreviewKind.isPreviewable(ShelfItem(kind: .file, title: "Img", content: "/tmp/unknownfile", fileExtension: "JPEG")))
        XCTAssertFalse(ItemPreviewKind.isPreviewable(ShelfItem(kind: .file, title: "Doc", content: "/tmp/a.pdf")))
        XCTAssertFalse(ItemPreviewKind.isPreviewable(ShelfItem(kind: .folder, title: "Dir", content: "/tmp/dir")))
        XCTAssertFalse(ItemPreviewKind.isPreviewable(ShelfItem(kind: .url, title: "U", content: "https://example.com")))
        XCTAssertFalse(ItemPreviewKind.isPreviewable(ShelfItem(kind: .application, title: "A", content: "/Applications/Terminal.app")))
        XCTAssertFalse(ItemPreviewKind.isPreviewable(ShelfItem(kind: .action, title: "Act", content: "/tmp", actionKind: .openPath)))
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("OpsNotchTests-\(UUID().uuidString)", isDirectory: true)
    }
}

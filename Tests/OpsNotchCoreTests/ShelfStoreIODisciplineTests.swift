import XCTest
@testable import OpsNotchCore

/// 存储层 I/O 纪律与增长控制:按需写盘、紧凑编码、条目软上限、捕获去重语义。
final class ShelfStoreIODisciplineTests: XCTestCase {
    // MARK: - load() 按需写盘

    func testLoadDoesNotRewriteUnchangedStore() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("shelf.json")
        try makeStoreJSON(items: [makeItem(index: 0, updatedAt: 100)]).write(to: url)
        let service = ShelfStoreService(rootURL: root)
        _ = try service.load()

        let bytesBefore = try Data(contentsOf: url)
        let modifiedBefore = try modificationDate(url)
        Thread.sleep(forTimeInterval: 0.05)

        _ = try service.load()

        XCTAssertEqual(try modificationDate(url), modifiedBefore)
        XCTAssertEqual(try Data(contentsOf: url), bytesBefore)
    }

    func testLoadRewritesOnLegacyMigration() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("shelf.json")
        let now = ShelfClock.now()
        let legacy = "[{\"id\":\"00000000-0000-0000-0000-000000000002\",\"kind\":\"command\",\"title\":\"cmd\",\"content\":\"ls -la\",\"pinned\":false,\"created_at\":\(now),\"updated_at\":\(now)}]"
        try legacy.data(using: .utf8)!.write(to: url)

        let store = try ShelfStoreService(rootURL: root).load()

        XCTAssertEqual(store.version, ShelfStore.currentVersion)
        let rootObject = try XCTUnwrap(try JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(rootObject["version"] as? Int, ShelfStore.currentVersion)
    }

    func testLoadRewritesWhenTTLExpiresItems() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("shelf.json")
        let expiredAt = ShelfClock.now() - 7_200
        try makeStoreJSON(items: [makeItem(index: 0, updatedAt: expiredAt)], tempTTLHours: 1)
            .write(to: url)

        let store = try ShelfStoreService(rootURL: root).load()

        XCTAssertTrue(store.items.isEmpty)
        let rootObject = try XCTUnwrap(try JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual((rootObject["items"] as? [Any])?.count, 0)
    }

    // MARK: - 紧凑编码

    func testCompactEncodingWritesParseableSingleLineJSON() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)

        _ = try service.addText("line1\nline2")

        let raw = try String(contentsOf: service.storeURL, encoding: .utf8)
        XCTAssertFalse(raw.contains("\n"), "紧凑编码不应产生格式化换行")
        let store = try service.load()
        XCTAssertEqual(store.items.first?.content, "line1\nline2")
    }

    // MARK: - 条目软上限

    func testItemLimitEvictsOldestUnprotectedItems() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let items = (0..<503).map { makeItem(index: $0, updatedAt: UInt64(1000 + $0)) }
        try makeStoreJSON(items: items).write(to: root.appendingPathComponent("shelf.json"))
        let service = ShelfStoreService(rootURL: root)

        let store = try service.addText("new item")

        XCTAssertEqual(store.items.count, ShelfStoreService.maxItems)
        for evicted in 0..<4 {
            XCTAssertFalse(store.items.contains { $0.content == "content \(evicted)" })
        }
        XCTAssertTrue(store.items.contains { $0.content == "content 4" })
        XCTAssertTrue(store.items.contains { $0.content == "new item" })
        XCTAssertEqual(try service.load().items.count, ShelfStoreService.maxItems)
    }

    func testItemLimitSkipsPinnedAndWorkingSetItems() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var items = (0..<503).map { makeItem(index: $0, updatedAt: UInt64(1000 + $0)) }
        items[0].pinned = true
        items[1].pinned = true
        let workingSet = [items[2].id, items[3].id]
        try makeStoreJSON(items: items, workingSet: workingSet)
            .write(to: root.appendingPathComponent("shelf.json"))
        let service = ShelfStoreService(rootURL: root)

        let store = try service.addText("new item")

        XCTAssertEqual(store.items.count, ShelfStoreService.maxItems)
        for exempt in 0..<4 {
            XCTAssertTrue(store.items.contains { $0.content == "content \(exempt)" }, "置顶/Working Set 条目不应被淘汰")
        }
        for evicted in 4..<8 {
            XCTAssertFalse(store.items.contains { $0.content == "content \(evicted)" })
        }
    }

    // MARK: - 捕获去重

    func testCaptureURLReusesExistingURLItem() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)

        let first = try service.captureURL("https://example.com/path")
        let firstID = try XCTUnwrap(first.items.first?.id)
        let second = try service.captureURL("  https://example.com/path  ")

        XCTAssertEqual(second.items.count, 1)
        XCTAssertEqual(second.items.first?.id, firstID)
        XCTAssertEqual(second.items.first?.title, "example.com")

        let third = try service.captureURL("https://other.com")
        XCTAssertEqual(third.items.count, 2)
    }

    func testCaptureURLRejectsNonHTTPScheme() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)

        XCTAssertThrowsError(try service.captureURL("ftp://example.com")) { error in
            XCTAssertTrue(error is ShelfStoreError)
        }
        XCTAssertTrue(try service.load().items.isEmpty)
    }

    func testManualAddURLStillAllowsDuplicateContent() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)

        _ = try service.addURL("https://example.com")
        let store = try service.addURL("https://example.com")

        XCTAssertEqual(store.items.count, 2)
    }

    func testCaptureTextMatchesStoredContentWithDifferentLineEndings() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ShelfStoreService(rootURL: root)

        _ = try service.addText("line1\r\nline2", title: "Manual")
        let captured = try service.captureText("line1\nline2")

        XCTAssertEqual(captured.items.count, 1)
        XCTAssertEqual(captured.items.first?.title, "Manual")
    }

    // MARK: - Helpers

    private func makeItem(index: Int, updatedAt: UInt64, pinned: Bool = false) -> ShelfItem {
        ShelfItem(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", index))!,
            kind: .text,
            title: "item \(index)",
            content: "content \(index)",
            pinned: pinned,
            createdAt: updatedAt,
            updatedAt: updatedAt
        )
    }

    private func makeStoreJSON(
        items: [ShelfItem],
        tempTTLHours: UInt64 = 0,
        workingSet: [UUID] = []
    ) throws -> Data {
        var settings = ShelfSettings(tempTTLHours: tempTTLHours)
        settings.workingSetItemIDs = workingSet
        return try JSONEncoder().encode(ShelfStore(items: items, settings: settings))
    }

    private func modificationDate(_ url: URL) throws -> Date {
        try XCTUnwrap(try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-store-io-tests-\(UUID().uuidString)", isDirectory: true)
    }
}

import XCTest
@testable import OpsNotchCore

final class SmartShelfRankingTests: XCTestCase {
    func testSemanticDetectionForOpsContent() {
        XCTAssertEqual(ShelfSemantic.kind(forText: "192.168.10.40"), .ipv4)
        XCTAssertEqual(ShelfSemantic.kind(forText: "ssh admin@192.168.10.40"), .ssh)
        XCTAssertEqual(ShelfSemantic.kind(forText: "kubectl get pods -n prod"), .command)
        XCTAssertEqual(ShelfSemantic.kind(forText: "docker compose up -d"), .command)
        XCTAssertEqual(ShelfSemantic.kind(forText: "/Users/me/project/config.yaml"), .path)
        XCTAssertEqual(ShelfSemantic.kind(forText: "~/Downloads"), .path)
        XCTAssertEqual(ShelfSemantic.kind(forText: "https://example.com/a"), .url)
        XCTAssertEqual(ShelfSemantic.kind(forText: "ordinary note"), .text)
    }

    func testIPv4ValidationRejectsInvalidValues() {
        XCTAssertFalse(ShelfSemantic.isIPv4("256.1.1.1"))
        XCTAssertFalse(ShelfSemantic.isIPv4("1.2.3"))
        XCTAssertFalse(ShelfSemantic.isIPv4("1.2.3.a"))
        XCTAssertTrue(ShelfSemantic.isIPv4("0.0.0.0"))
        XCTAssertTrue(ShelfSemantic.isIPv4("255.255.255.255"))
    }

    func testTerminalContextPrefersCommandOverPlainText() {
        let now: UInt64 = 10_000
        let command = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            kind: .text,
            title: "Command",
            content: "kubectl get pods",
            createdAt: now - 10,
            updatedAt: now - 10
        )
        let note = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            kind: .text,
            title: "Note",
            content: "ordinary note",
            createdAt: now - 10,
            updatedAt: now - 10
        )

        let ordered = SmartShelfRanking.ordered([note, command], appContext: .terminal, now: now)
        XCTAssertEqual(ordered.first?.id, command.id)
    }

    func testFinderContextPrefersFileOverTextAtEqualRecency() {
        let now: UInt64 = 20_000
        let file = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            kind: .file,
            title: "Config",
            content: "/tmp/config.yaml",
            createdAt: now - 20,
            updatedAt: now - 20
        )
        let note = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            kind: .text,
            title: "Note",
            content: "plain text",
            createdAt: now - 20,
            updatedAt: now - 20
        )

        let ordered = SmartShelfRanking.ordered([note, file], appContext: .finder, now: now)
        XCTAssertEqual(ordered.first?.id, file.id)
    }

    func testQueryRelevanceOutweighsContextAffinity() {
        let now: UInt64 = 30_000
        let matchingText = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            kind: .text,
            title: "prod-cluster",
            content: "important deployment note",
            createdAt: now - 300,
            updatedAt: now - 300
        )
        let terminalFavored = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            kind: .text,
            title: "command prod-cluster helper",
            content: "kubectl get pods",
            createdAt: now,
            updatedAt: now
        )

        let ordered = SmartShelfRanking.ordered(
            [terminalFavored, matchingText],
            query: "prod-cluster",
            appContext: .terminal,
            now: now
        )
        XCTAssertEqual(ordered.first?.id, matchingText.id)
    }

    func testUsageFrequencyContributesToRanking() {
        let now: UInt64 = 40_000
        let frequent = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
            kind: .text,
            title: "Frequent",
            content: "note",
            createdAt: now - 100,
            updatedAt: now - 100,
            useCount: 16,
            lastUsedAt: now - 100
        )
        let unused = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            kind: .text,
            title: "Unused",
            content: "note",
            createdAt: now - 100,
            updatedAt: now - 100
        )

        let ordered = SmartShelfRanking.ordered([unused, frequent], now: now)
        XCTAssertEqual(ordered.first?.id, frequent.id)
    }

    func testLegacyModelsDecodeWithV2Defaults() throws {
        let itemJSON = #"{"id":"00000000-0000-0000-0000-000000000009","kind":"text","title":"Legacy","content":"hello","pinned":false,"created_at":1,"updated_at":2}"#.data(using: .utf8)!
        let item = try JSONDecoder().decode(ShelfItem.self, from: itemJSON)
        XCTAssertEqual(item.useCount, 0)
        XCTAssertEqual(item.lastUsedAt, 0)

        let settingsJSON = #"{"temp_ttl_hours":24,"add_mode":"reference","display_target":"all","language":"zh-CN","finder_reveal_app_name":"gf.app","finder_default_path":"~","finder_quick_paths":[]}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(ShelfSettings.self, from: settingsJSON)
        XCTAssertTrue(settings.workingSetItemIDs.isEmpty)
    }

    func testRecordUseAndWorkingSetCleanup() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-smart-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ShelfStoreService(rootURL: root)
        var value = try store.addText("kubectl get pods", title: "Pods")
        let id = try XCTUnwrap(value.items.first?.id)
        var settings = value.settings
        settings.workingSetItemIDs = [id]
        value = try store.updateSettings(settings)
        XCTAssertEqual(value.settings.workingSetItemIDs, [id])

        value = try store.recordUse(id: id, now: 123_456)
        let used = try XCTUnwrap(value.items.first(where: { $0.id == id }))
        XCTAssertEqual(used.useCount, 1)
        XCTAssertEqual(used.lastUsedAt, 123_456)
        XCTAssertEqual(used.updatedAt, 123_456)

        value = try store.remove(ids: Set([id]))
        XCTAssertTrue(value.settings.workingSetItemIDs.isEmpty)
    }
}

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

    func testQueryMatchTierCannotBeOvertakenByContextOrFrequency() {
        let now: UInt64 = 1_000_000
        let exact = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            kind: .text,
            title: "prod",
            content: "plain note",
            createdAt: now - 300_000,
            updatedAt: now - 300_000
        )
        let prefixCommand = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            kind: .text,
            title: "prod deploy helper",
            content: "kubectl get pods",
            createdAt: now,
            updatedAt: now,
            useCount: 10_000,
            lastUsedAt: now
        )

        let ordered = SmartShelfRanking.ordered(
            [prefixCommand, exact],
            query: "prod",
            appContext: .terminal,
            now: now
        )
        XCTAssertEqual(ordered.first?.id, exact.id)
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

    func testClearRecentPreservesWorkingSetItems() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("opsnotch-clear-recent-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ShelfStoreService(rootURL: root)
        var value = try store.addText("keep me", title: "Working")
        let workingID = try XCTUnwrap(value.items.first?.id)
        value = try store.addText("remove me", title: "Recent")
        let recentID = try XCTUnwrap(value.items.first(where: { $0.id != workingID })?.id)

        var settings = value.settings
        settings.workingSetItemIDs = [workingID]
        _ = try store.updateSettings(settings)

        value = try store.clearRecent()
        XCTAssertNotNil(value.items.first(where: { $0.id == workingID }))
        XCTAssertNil(value.items.first(where: { $0.id == recentID }))
        XCTAssertEqual(value.settings.workingSetItemIDs, [workingID])
    }

    /// 旧实现的参考版本:排序比较器内逐次调用 score。评分预计算重构后,输出必须与它逐项一致。
    private func legacyOrdered(
        _ items: [ShelfItem],
        query: String,
        kindFilter: ShelfKindFilter,
        appContext: AppContextKind,
        now: UInt64
    ) -> [ShelfItem] {
        items
            .filter { ShelfLogic.matches($0, query: query, kindFilter: kindFilter) }
            .sorted { lhs, rhs in
                let left = SmartShelfRanking.score(item: lhs, query: query, appContext: appContext, now: now)
                let right = SmartShelfRanking.score(item: rhs, query: query, appContext: appContext, now: now)
                if left != right { return left > right }
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    func testPrecomputedScoringKeepsLegacyOrdering() {
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next(_ bound: UInt64) -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state % bound
        }

        let contents = [
            "kubectl get pods -n prod", "https://example.com/deploy", "/Users/me/project/config.yaml",
            "ssh admin@192.168.10.40", "192.168.10.40", "ordinary note", "prod deploy helper",
            "docker compose up -d", "~/Downloads/archive", "git push origin main"
        ]
        let kinds: [ShelfKind] = [.text, .url, .file, .folder, .application, .action]
        let now: UInt64 = 1_000_000
        var items: [ShelfItem] = []
        for index in 0..<200 {
            let kind = kinds[Int(next(UInt64(kinds.count)))]
            let actionKind: SafeActionKind? = kind == .action
                ? (next(2) == 0 ? .openPath : .openURL) : nil
            items.append(ShelfItem(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", index))!,
                kind: kind,
                title: contents[Int(next(UInt64(contents.count)))],
                content: contents[Int(next(UInt64(contents.count)))] + " #\(index)",
                pinned: next(4) == 0,
                createdAt: now - next(200_000),
                updatedAt: now - next(200_000),
                actionKind: actionKind,
                useCount: next(50),
                lastUsedAt: now - next(200_000)
            ))
        }

        let queries = ["", "prod", "kubectl", "config"]
        let contexts: [AppContextKind] = [.generic, .finder, .terminal, .browser]
        for query in queries {
            for context in contexts {
                for filter in ShelfKindFilter.allCases {
                    let optimized = SmartShelfRanking.ordered(
                        items, query: query, kindFilter: filter, appContext: context, now: now
                    )
                    let reference = legacyOrdered(items, query: query, kindFilter: filter, appContext: context, now: now)
                    XCTAssertEqual(optimized.map(\.id), reference.map(\.id))
                }
            }
        }
    }
}

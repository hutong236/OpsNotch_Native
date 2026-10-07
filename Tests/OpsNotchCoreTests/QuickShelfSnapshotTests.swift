import XCTest
@testable import OpsNotchCore

final class QuickShelfSnapshotTests: XCTestCase {
    func testCommandQueriesFilterBeforeRankingAndKeepStableIDs() {
        let file = ShelfItem(kind: .file, title: "Report", content: "/tmp/report")
        let folder = ShelfItem(kind: .folder, title: "Report folder", content: "/tmp/reports")
        let favorite = ShelfItem(kind: .text, title: "Report token", content: "token", pinned: true)
        let recent = ShelfItem(kind: .text, title: "Report token", content: "token")
        let items = [file, folder, favorite, recent]
        func result(_ query: String, filter: ShelfKindFilter = .all) -> Set<UUID> {
            Set(QuickShelfItemSnapshotBuilder.build(items: items, workingSetItemIDs: [favorite.id],
                query: query, kindFilter: filter, appContext: .generic, now: 1_000).visibleItems.map(\.id))
        }
        XCTAssertEqual(result("type:file report", filter: .text), [file.id, folder.id])
        XCTAssertEqual(result("type:folder report"), [folder.id])
        XCTAssertEqual(result("@fav token"), [favorite.id])
        XCTAssertEqual(result("report"), Set(items.map(\.id)))
        XCTAssertTrue(result("type:unknown report").isEmpty)
        for query in ["d", "d2", "~/Downloads", "/tmp/report"] {
            XCTAssertTrue(result(query).isEmpty, query)
        }
    }

    func testRevisionCacheBuildsOncePerRevision() {
        let cache = QuickShelfSnapshotCache<Int>()
        var builds = 0

        let first = cache.value(for: 1) {
            builds += 1
            return 42
        }
        let second = cache.value(for: 1) {
            builds += 1
            return 99
        }

        XCTAssertEqual(first, 42)
        XCTAssertEqual(second, 42)
        XCTAssertEqual(builds, 1)

        let third = cache.value(for: 2) {
            builds += 1
            return 99
        }

        XCTAssertEqual(third, 99)
        XCTAssertEqual(builds, 2)
    }

    func testCachedSnapshotStaysStableUntilQueryRevisionChanges() {
        let item = ShelfItem(kind: .text, title: "Needle", content: "needle")
        let cache = QuickShelfSnapshotCache<QuickShelfItemSnapshot>()
        var query = "needle"
        var builds = 0
        func snapshot(_ revision: UInt64) -> QuickShelfItemSnapshot {
            cache.value(for: revision) {
                builds += 1
                return QuickShelfItemSnapshotBuilder.build(items: [item], workingSetItemIDs: [],
                    query: query, kindFilter: .all, appContext: .generic, now: 1_000)
            }
        }
        XCTAssertEqual(snapshot(0).visibleItems.map(\.id), [item.id])
        query = "missing"
        XCTAssertEqual(snapshot(0).visibleItems.map(\.id), [item.id])
        XCTAssertEqual(builds, 1)
        XCTAssertTrue(snapshot(1).visibleItems.isEmpty)
        XCTAssertEqual(builds, 2)
    }

    func testRevisionCacheRemoveAllForcesRebuild() {
        let cache = QuickShelfSnapshotCache<Int>()
        var builds = 0

        _ = cache.value(for: 7) {
            builds += 1
            return 1
        }
        cache.removeAll()
        let rebuilt = cache.value(for: 7) {
            builds += 1
            return 2
        }

        XCTAssertEqual(rebuilt, 2)
        XCTAssertEqual(builds, 2)
    }

    func testItemSnapshotSeparatesWorkingPinnedAndRecentWithoutDuplication() {
        let now: UInt64 = 1_000_000
        let working = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
            kind: .text,
            title: "Working",
            content: "working item",
            pinned: true,
            createdAt: now - 30,
            updatedAt: now - 30
        )
        let pinned = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
            kind: .text,
            title: "Pinned",
            content: "pinned item",
            pinned: true,
            createdAt: now - 20,
            updatedAt: now - 20
        )
        let recent = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000203")!,
            kind: .text,
            title: "Recent",
            content: "recent item",
            pinned: false,
            createdAt: now - 10,
            updatedAt: now - 10
        )

        let snapshot = QuickShelfItemSnapshotBuilder.build(
            items: [working, pinned, recent],
            workingSetItemIDs: [working.id],
            query: "",
            kindFilter: .all,
            appContext: .generic,
            now: now
        )

        XCTAssertEqual(snapshot.working.map(\.id), [working.id])
        XCTAssertEqual(snapshot.pinned.map(\.id), [pinned.id])
        XCTAssertEqual(snapshot.recent.map(\.id), [recent.id])
        XCTAssertEqual(snapshot.visibleItems.map(\.id), [working.id, pinned.id, recent.id])
    }
    func testItemSnapshotKeepsNewestRecentFirstAndExcludesWorkingSetFromPinned() {
        let now: UInt64 = 2_000_000
        let workingPinned = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000211")!,
            kind: .text,
            title: "Working pinned",
            content: "working",
            pinned: true,
            createdAt: now - 300,
            updatedAt: now - 300
        )
        let olderRecent = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000212")!,
            kind: .text,
            title: "Older recent",
            content: "older",
            createdAt: now - 200,
            updatedAt: now - 200
        )
        let newestRecent = ShelfItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000213")!,
            kind: .text,
            title: "Newest recent",
            content: "newest",
            createdAt: now - 1,
            updatedAt: now - 1
        )

        let snapshot = QuickShelfItemSnapshotBuilder.build(
            items: [olderRecent, workingPinned, newestRecent],
            workingSetItemIDs: [workingPinned.id],
            query: "",
            kindFilter: .all,
            appContext: .generic,
            now: now
        )

        XCTAssertEqual(snapshot.working.map(\.id), [workingPinned.id])
        XCTAssertTrue(snapshot.pinned.isEmpty)
        XCTAssertEqual(snapshot.recent.map(\.id), [newestRecent.id, olderRecent.id])
        XCTAssertEqual(
            snapshot.visibleItems.map(\.id),
            [workingPinned.id, newestRecent.id, olderRecent.id]
        )
    }
}

import XCTest
@testable import OpsNotchCore

final class QuickShelfSnapshotTests: XCTestCase {
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
}

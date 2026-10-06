import XCTest
@testable import OpsNotchCore

final class SmartShelfRankingCacheTests: XCTestCase {
    func testRepeatedIdenticalRankingUsesMemoizedResult() {
        SmartShelfRanking._resetCacheForTesting()
        let now: UInt64 = 500_000
        let items = [
            ShelfItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                kind: .text,
                title: "Command",
                content: "kubectl get pods",
                createdAt: now - 30,
                updatedAt: now - 30
            ),
            ShelfItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
                kind: .text,
                title: "Note",
                content: "ordinary note",
                createdAt: now - 20,
                updatedAt: now - 20
            ),
            ShelfItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
                kind: .text,
                title: "Newest",
                content: "latest note",
                createdAt: now - 1,
                updatedAt: now - 1
            )
        ]

        let first = SmartShelfRanking.ordered(items, appContext: .terminal, now: now)
        let afterFirst = SmartShelfRanking._cacheStatsForTesting()
        XCTAssertEqual(afterFirst.hits, 0)
        XCTAssertEqual(afterFirst.misses, 1)

        let second = SmartShelfRanking.ordered(items, appContext: .terminal, now: now)
        let afterSecond = SmartShelfRanking._cacheStatsForTesting()

        XCTAssertEqual(first, second)
        XCTAssertEqual(afterSecond.hits, 1)
        XCTAssertEqual(afterSecond.misses, 1)
    }
}

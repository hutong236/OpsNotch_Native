import XCTest
@testable import OpsNotchCore

final class FinderQuickPathRankingTests: XCTestCase {
    func testRecentUseChangesVisualOrderButKeepsFixedSlots() {
        let first = FinderQuickPath(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            label: "One",
            path: "/one",
            useCount: 10,
            lastUsedAt: 100
        )
        let second = FinderQuickPath(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            label: "Two",
            path: "/two",
            useCount: 1,
            lastUsedAt: 200
        )

        let ranked = FinderQuickPathRanking.ranked([first, second])

        XCTAssertEqual(ranked.map(\.item.label), ["Two", "One"])
        XCTAssertEqual(ranked.map(\.slot), [2, 1])
    }

    func testFrequencyBreaksEqualRecencyTie() {
        let lessUsed = FinderQuickPath(label: "Less", path: "/less", useCount: 2, lastUsedAt: 100)
        let moreUsed = FinderQuickPath(label: "More", path: "/more", useCount: 7, lastUsedAt: 100)

        let ranked = FinderQuickPathRanking.ranked([lessUsed, moreUsed])

        XCTAssertEqual(ranked.map(\.item.label), ["More", "Less"])
        XCTAssertEqual(ranked.map(\.slot), [2, 1])
    }

    func testNeverUsedItemsKeepNumericSlotOrder() {
        let paths = [
            FinderQuickPath(label: "One", path: "/one"),
            FinderQuickPath(label: "Two", path: "/two"),
            FinderQuickPath(label: "Three", path: "/three")
        ]

        let ranked = FinderQuickPathRanking.ranked(paths)

        XCTAssertEqual(ranked.map(\.slot), [1, 2, 3])
    }

    func testLegacyQuickPathDecodesWithZeroUsageStats() throws {
        let json = #"{"id":"00000000-0000-0000-0000-000000000001","label":"Legacy","path":"/tmp"}"#.data(using: .utf8)!

        let item = try JSONDecoder().decode(FinderQuickPath.self, from: json)

        XCTAssertEqual(item.useCount, 0)
        XCTAssertEqual(item.lastUsedAt, 0)
    }
}

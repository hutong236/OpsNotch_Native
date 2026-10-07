import XCTest
@testable import OpsNotchCore

final class ShelfSectionModelTests: XCTestCase {
    func testDeclaredSectionOrder() {
        XCTAssertEqual(
            ShelfSectionKind.allCases,
            [.context, .now, .favorites, .recent, .results]
        )
    }

    func testVisibleSectionsFollowDeclaredOrderRegardlessOfCountInsertionOrder() {
        let insertionOrders: [[ShelfSectionKind]] = [
            [.results, .favorites, .context, .recent, .now],
            [.now, .recent, .context, .favorites, .results]
        ]

        for insertionOrder in insertionOrders {
            var counts: [ShelfSectionKind: Int] = [:]
            for section in insertionOrder {
                counts[section] = 1
            }

            XCTAssertEqual(
                ShelfSectionModel.visibleSections(itemCounts: counts),
                [.context, .now, .favorites, .recent, .results]
            )
        }
    }

    func testAbsentZeroAndNegativeCountsAreOmitted() {
        let counts: [ShelfSectionKind: Int] = [
            .results: 3,
            .now: 0,
            .favorites: -1,
            .recent: 2
        ]

        XCTAssertEqual(
            ShelfSectionModel.visibleSections(itemCounts: counts),
            [.recent, .results]
        )
    }

    func testNoCountsProducesNoVisibleSections() {
        XCTAssertEqual(ShelfSectionModel.visibleSections(itemCounts: [:]), [])
    }
}

#if os(macOS)
import XCTest
@testable import OpsNotchApp

final class ShelfDisplayTextTests: XCTestCase {
    func testShortAndExactLimitTextAreUnchanged() {
        XCTAssertEqual(ShelfDisplayText.bounded("中文🙂", limit: 3), "中文🙂")
        XCTAssertEqual(ShelfDisplayText.bounded("", limit: 3), "")
        XCTAssertEqual(ShelfDisplayText.bounded("abc", limit: 3), "abc")
    }

    func testLongSingleLineIsBounded() {
        let original = String(repeating: "abc中文🙂", count: 100_000)
        let result = ShelfDisplayText.bounded(original)
        XCTAssertEqual(result.unicodeScalars.count, 513)
        XCTAssertTrue(result.hasSuffix("…"))
        XCTAssertEqual(String(result.unicodeScalars.dropLast()), String(original.unicodeScalars.prefix(512)))
    }

    func testPathologicalCombiningSequenceHasScalarBudget() {
        let original = "a" + String(repeating: "\u{0301}", count: 50_000)
        let result = ShelfDisplayText.bounded(original, limit: 32)
        XCTAssertEqual(result.unicodeScalars.count, 33)
        XCTAssertTrue(result.hasSuffix("…"))
    }
}
#endif

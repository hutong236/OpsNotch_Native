import XCTest
@testable import OpsNotchCore

final class DesktopCommandParserTests: XCTestCase {
    func testParsesSpacedDesktopSelectionCommands() {
        XCTAssertEqual(DesktopCommandParser.parse("d 1"), .switchTo(index: 1))
        XCTAssertEqual(DesktopCommandParser.parse("D 3"), .switchTo(index: 3))
        XCTAssertEqual(DesktopCommandParser.parse("d    12"), .switchTo(index: 12))
        XCTAssertEqual(DesktopCommandParser.parse("desktop 4"), .switchTo(index: 4))
        XCTAssertEqual(DesktopCommandParser.parse("桌面 5"), .switchTo(index: 5))
    }

    func testParsesDesktopListSuggestions() {
        XCTAssertEqual(DesktopCommandParser.parse("d"), .list)
        XCTAssertEqual(DesktopCommandParser.parse(" desktop "), .list)
        XCTAssertEqual(DesktopCommandParser.parse("桌面"), .list)
    }

    func testRejectsCompactOrAmbiguousSearchTerms() {
        XCTAssertNil(DesktopCommandParser.parse(""))
        XCTAssertNil(DesktopCommandParser.parse("d1"))
        XCTAssertNil(DesktopCommandParser.parse("d2"))
        XCTAssertNil(DesktopCommandParser.parse("d 0"))
        XCTAssertNil(DesktopCommandParser.parse("d 01"))
        XCTAssertNil(DesktopCommandParser.parse("dx"))
        XCTAssertNil(DesktopCommandParser.parse("ddd"))
        XCTAssertNil(DesktopCommandParser.parse("docker"))
        XCTAssertNil(DesktopCommandParser.parse("desktop app"))
        XCTAssertNil(DesktopCommandParser.parse("my d 1"))
    }
}

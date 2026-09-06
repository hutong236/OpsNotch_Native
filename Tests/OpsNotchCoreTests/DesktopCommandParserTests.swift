import XCTest
@testable import OpsNotchCore

final class DesktopCommandParserTests: XCTestCase {
    func testParsesDesktopSelectionCommands() {
        XCTAssertEqual(DesktopCommandParser.parse("d1"), .switchTo(index: 1))
        XCTAssertEqual(DesktopCommandParser.parse("D3"), .switchTo(index: 3))
        XCTAssertEqual(DesktopCommandParser.parse("d12"), .switchTo(index: 12))
        XCTAssertEqual(DesktopCommandParser.parse("desktop 4"), .switchTo(index: 4))
        XCTAssertEqual(DesktopCommandParser.parse("桌面 5"), .switchTo(index: 5))
    }

    func testParsesDesktopListCommands() {
        XCTAssertEqual(DesktopCommandParser.parse("d"), .list)
        XCTAssertEqual(DesktopCommandParser.parse(" desktop "), .list)
        XCTAssertEqual(DesktopCommandParser.parse("桌面"), .list)
    }

    func testRejectsAmbiguousOrInvalidCommands() {
        XCTAssertNil(DesktopCommandParser.parse(""))
        XCTAssertNil(DesktopCommandParser.parse("d0"))
        XCTAssertNil(DesktopCommandParser.parse("d01"))
        XCTAssertNil(DesktopCommandParser.parse("dx"))
        XCTAssertNil(DesktopCommandParser.parse("download"))
        XCTAssertNil(DesktopCommandParser.parse("my d1"))
    }
}

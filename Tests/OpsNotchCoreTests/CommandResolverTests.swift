import XCTest
@testable import OpsNotchCore

final class CommandResolverTests: XCTestCase {
    func testDesktopCommandsResolveOnlyCompletePositiveIndices() {
        XCTAssertEqual(CommandResolver.resolve("d"), .desktopList)
        XCTAssertEqual(CommandResolver.resolve(" D "), .desktopList)
        XCTAssertEqual(CommandResolver.resolve("d2"), .desktopSwitch(index: 2))
        XCTAssertEqual(CommandResolver.resolve("d 2"), .desktopSwitch(index: 2))
        XCTAssertEqual(CommandResolver.resolve("D\t12"), .desktopSwitch(index: 12))
        for query in ["d0", "d 0", "d01", "d -2", "d2 report", "d 2 3", "docker", "d99999999999999999999999999"] {
            XCTAssertNil(CommandResolver.resolve(query), query)
        }
    }

    func testFinderPathsPreserveOriginalCaseAndSpacesWithoutExpansion() {
        XCTAssertEqual(CommandResolver.resolve("~/Downloads"), .finderPath("~/Downloads"))
        XCTAssertEqual(CommandResolver.resolve(" /Users/Ada/My Reports "), .finderPath("/Users/Ada/My Reports"))
        XCTAssertEqual(CommandResolver.resolve("/"), .finderPath("/"))
        for query in ["Downloads/Report", "~ada/Downloads", "file:///Users/Ada", "https://example.com"] {
            XCTAssertNil(CommandResolver.resolve(query), query)
        }
    }

    func testTypeFiltersPreserveResidualQuery() {
        XCTAssertEqual(CommandResolver.resolve("type:file report"), .typeFilter(kind: .file, query: "report"))
        XCTAssertEqual(CommandResolver.resolve(" TYPE:FILE   Quarterly  Report.PDF "), .typeFilter(kind: .file, query: "Quarterly  Report.PDF"))
        XCTAssertEqual(CommandResolver.resolve("type:folder Plans"), .typeFilter(kind: .folder, query: "Plans"))
        XCTAssertEqual(CommandResolver.resolve("type:url Example"), .typeFilter(kind: .url, query: "Example"))
        XCTAssertEqual(CommandResolver.resolve("type:application Editor"), .typeFilter(kind: .application, query: "Editor"))
        XCTAssertEqual(CommandResolver.resolve("type:action Launch"), .typeFilter(kind: .action, query: "Launch"))
        XCTAssertEqual(CommandResolver.resolve("type:text Notes"), .typeFilter(kind: .text, query: "Notes"))
        XCTAssertEqual(CommandResolver.resolve("type:file"), .typeFilter(kind: .file, query: ""))
        for query in ["type:command rm", "type:ip server", "type:unknown Report", "type: file", "report type:file"] {
            XCTAssertNil(CommandResolver.resolve(query), query)
        }
    }

    func testFavoritesFilterRequiresWholeTokenAndPreservesResidualQuery() {
        XCTAssertEqual(CommandResolver.resolve("@fav token"), .favorites(query: "token"))
        XCTAssertEqual(CommandResolver.resolve(" @FAV\tAPI  Token "), .favorites(query: "API  Token"))
        XCTAssertEqual(CommandResolver.resolve("@fav"), .favorites(query: ""))
        XCTAssertNil(CommandResolver.resolve("@favorite token"))
        XCTAssertNil(CommandResolver.resolve("@favtoken"))
    }

    func testArbitraryShellTextAndOrdinarySearchProduceNoCommandIntent() {
        for query in ["", "  ", "report", "ssh root@host", "kubectl get pods", "rm -rf /tmp/report", "d2; rm file", "$(whoami)", "open ~/Downloads"] {
            XCTAssertNil(CommandResolver.resolve(query), query)
        }
    }
}

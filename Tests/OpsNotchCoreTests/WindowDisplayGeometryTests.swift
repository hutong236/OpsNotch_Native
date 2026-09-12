import XCTest
@testable import OpsNotchCore

final class WindowDisplayGeometryTests: XCTestCase {
    func testAppKitToAXCoordinatesForDisplaysAboveAndBelow() {
        let above = CGRect(x: 0, y: 900, width: 1920, height: 1080)
        let below = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
        XCTAssertEqual(WindowDisplayGeometry.quartzRect(above, primaryTop: 900), CGRect(x: 0, y: -1080, width: 1920, height: 1080))
        XCTAssertEqual(WindowDisplayGeometry.quartzRect(below, primaryTop: 900), CGRect(x: 0, y: 900, width: 1920, height: 1080))
    }

    func testLeftDisplayRetainsNegativeCoordinatesAndDockInsets() {
        let visible = CGRect(x: -1860, y: 40, width: 1860, height: 1015)
        XCTAssertEqual(WindowDisplayGeometry.quartzRect(visible, primaryTop: 900), CGRect(x: -1860, y: -155, width: 1860, height: 1015))
    }

    func testMovingBetweenDifferentSizedDisplaysPreservesPointSize() throws {
        // Source may be Retina; destination may be 1x. Neither uses pixel sizes.
        let source = CGRect(x: 0, y: 30, width: 1440, height: 840)
        let destination = CGRect(x: 1440, y: 25, width: 1920, height: 1030)
        let frame = try XCTUnwrap(WindowDisplayGeometry.destinationFrame(
            window: CGRect(x: 420, y: 220, width: 600, height: 460), source: source, destination: destination))
        XCTAssertEqual(frame, CGRect(x: 2100, y: 310, width: 600, height: 460))
        XCTAssertTrue(WindowDisplayGeometry.contains(frame, in: destination))
    }

    func testOffscreenSourceWindowIsClampedIntoLeftDestination() throws {
        let destination = CGRect(x: -1280, y: 25, width: 1280, height: 975)
        let frame = try XCTUnwrap(WindowDisplayGeometry.destinationFrame(
            window: CGRect(x: -300, y: 1000, width: 800, height: 600),
            source: CGRect(x: 0, y: 25, width: 1440, height: 875), destination: destination))
        XCTAssertEqual(frame, CGRect(x: -1280, y: 400, width: 800, height: 600))
    }

    func testLargeWindowShrinksOnlyAsNeededForSmallerDisplay() throws {
        let destination = CGRect(x: 0, y: -740, width: 1000, height: 740)
        let frame = try XCTUnwrap(WindowDisplayGeometry.destinationFrame(
            window: CGRect(x: 100, y: 40, width: 1400, height: 900),
            source: CGRect(x: 0, y: 25, width: 1920, height: 1055), destination: destination))
        XCTAssertEqual(frame, destination)
    }

    func testWindowMustFitEntirelyRatherThanJustTouchTargetDisplay() {
        let visible = CGRect(x: 1440, y: 25, width: 1920, height: 1030)
        XCTAssertFalse(WindowDisplayGeometry.contains(CGRect(x: 1300, y: 100, width: 800, height: 600), in: visible))
        XCTAssertFalse(WindowDisplayGeometry.contains(CGRect(x: 1500, y: 900, width: 800, height: 600), in: visible))
        XCTAssertTrue(WindowDisplayGeometry.contains(CGRect(x: 1440, y: 25, width: 800, height: 600), in: visible))
    }

    func testInvalidGeometryCannotProduceAMove() {
        let valid = CGRect(x: 0, y: 25, width: 1440, height: 875)
        XCTAssertNil(WindowDisplayGeometry.destinationFrame(window: valid, source: valid, destination: .zero))
        let invalid = CGRect(x: CGFloat.nan, y: 0, width: 800, height: 600)
        XCTAssertNil(WindowDisplayGeometry.destinationFrame(window: invalid, source: valid, destination: valid))
        XCTAssertFalse(WindowDisplayGeometry.contains(invalid, in: valid))
    }
}

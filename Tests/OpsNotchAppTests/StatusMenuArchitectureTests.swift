#if os(macOS)
import XCTest
@testable import OpsNotchApp

@MainActor
final class StatusMenuArchitectureTests: XCTestCase {
    func testStatusMenuUsesApprovedThreePointOhControlSet() {
        XCTAssertEqual(
            StatusBarController.menuLayout,
            [.openShelf, .keepShelfOpen, .settings, .quit]
        )
    }
}
#endif

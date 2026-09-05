import XCTest
@testable import OpsNotchCore

final class WorkspaceShortcutTests: XCTestCase {
    func testDefaultWorkspaceProfiles() {
        let profiles = WorkspaceProfile.defaults

        XCTAssertFalse(profiles.isEmpty)
        XCTAssertEqual(profiles.first?.name, "开发环境")
        XCTAssertTrue(profiles.allSatisfy { $0.enabled })
    }

    func testWorkspaceStoreFiltersDisabledProfiles() {
        let disabled = WorkspaceProfile(
            name: "Disabled",
            icon: "🚫",
            steps: 1,
            enabled: false
        )

        let store = WorkspaceStore(profiles: [disabled])
        XCTAssertTrue(store.enabledProfiles().isEmpty)
    }
}

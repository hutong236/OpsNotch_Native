import XCTest
@testable import OpsNotchCore

final class WorkspaceStoreTests: XCTestCase {
    func testEnabledProfilesOnlyReturnsEnabledItems() {
        let store = WorkspaceStore(profiles: [
            WorkspaceProfile(id: UUID(), name: "Dev", icon: "💻", steps: 1, enabled: true),
            WorkspaceProfile(id: UUID(), name: "Disabled", icon: "⏸", steps: 1, enabled: false)
        ])

        XCTAssertEqual(store.enabledProfiles().count, 1)
        XCTAssertEqual(store.enabledProfiles().first?.name, "Dev")
    }
}

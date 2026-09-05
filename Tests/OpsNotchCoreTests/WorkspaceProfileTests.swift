import XCTest
@testable import OpsNotchCore

final class WorkspaceProfileTests: XCTestCase {
    func testDefaultWorkspaceProfilesAreAvailable() {
        XCTAssertEqual(WorkspaceProfile.defaults.count, 3)
        XCTAssertEqual(WorkspaceProfile.defaults.first?.name, "开发环境")
    }

    func testWorkspaceProfileCodableRoundTrip() throws {
        let item = WorkspaceProfile(name: "测试", icon: "🧪", steps: 1)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(WorkspaceProfile.self, from: data)
        XCTAssertEqual(item, decoded)
    }
}

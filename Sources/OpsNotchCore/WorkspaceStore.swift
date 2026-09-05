import Foundation

public struct WorkspaceStore {
    public var profiles: [WorkspaceProfile]

    public init(profiles: [WorkspaceProfile] = WorkspaceProfile.defaults) {
        self.profiles = profiles
    }

    public func enabledProfiles() -> [WorkspaceProfile] {
        profiles.filter { $0.enabled }
    }
}

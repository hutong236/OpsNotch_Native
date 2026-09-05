import Foundation

/// User-defined workspace shortcut configuration.
///
/// A workspace only describes a lightweight Space movement action. It does
/// not launch applications or execute commands.
public struct WorkspaceProfile: Codable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var icon: String
    public var steps: Int
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        steps: Int,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.steps = steps
        self.enabled = enabled
    }
}

public extension WorkspaceProfile {
    static let defaults: [WorkspaceProfile] = [
        WorkspaceProfile(name: "开发环境", icon: "💻", steps: 1),
        WorkspaceProfile(name: "运维环境", icon: "🛠", steps: 2),
        WorkspaceProfile(name: "文档环境", icon: "📄", steps: 3)
    ]
}

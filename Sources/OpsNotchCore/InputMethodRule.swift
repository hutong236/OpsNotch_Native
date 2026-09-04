import Foundation

public enum InputMethodRuleMode: String, Codable, CaseIterable, Sendable {
    case fixed
    case remember
    case keep
}

public struct InputMethodRule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var bundleID: String
    public var appName: String
    public var mode: InputMethodRuleMode
    public var inputSourceID: String?

    public init(
        id: UUID = UUID(),
        bundleID: String,
        appName: String,
        mode: InputMethodRuleMode = .keep,
        inputSourceID: String? = nil
    ) {
        self.id = id
        self.bundleID = bundleID
        self.appName = appName
        self.mode = mode
        self.inputSourceID = inputSourceID
    }
}
import Foundation

public enum SafeActionValidator {
    public static func isHTTPURL(_ value: String) -> Bool {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              url.host != nil else { return false }
        return scheme == "http" || scheme == "https"
    }

    public static func isAbsoluteLocalPath(_ value: String) -> Bool {
        value.hasPrefix("/")
    }

    public static func validate(kind: SafeActionKind, content: String) -> Bool {
        switch kind {
        case .openURL: return isHTTPURL(content)
        case .openPath: return isAbsoluteLocalPath(content)
        }
    }
}

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

    /// 归一化 openPath 输入:仅接受 `~` / `~/...`(展开为当前用户绝对路径);
    /// `~user/...`(其他用户主目录)与相对路径返回 nil。
    public static func expandedLocalPath(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "~" || trimmed.hasPrefix("~/") else { return nil }
        let expanded = (trimmed as NSString).expandingTildeInPath
        return isAbsoluteLocalPath(expanded) ? expanded : nil
    }

    /// 归一化并校验安全操作内容,返回应落盘的规范形式;无效返回 nil。
    /// openURL 去首尾空白后仍须是 http(s) URL;openPath 经 `~` 展开后仍须是本地绝对路径。
    public static func normalizedActionContent(kind: SafeActionKind, content: String) -> String? {
        switch kind {
        case .openURL:
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return isHTTPURL(trimmed) ? trimmed : nil
        case .openPath:
            return expandedLocalPath(content)
        }
    }

    public static func validate(kind: SafeActionKind, content: String) -> Bool {
        switch kind {
        case .openURL: return isHTTPURL(content)
        case .openPath: return isAbsoluteLocalPath(content)
        }
    }
}

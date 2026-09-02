#if os(macOS)
import AppKit
import Foundation

/// 打开 Finder 目录时优先复用已经展示同一路径的 Finder 窗口。
/// Finder 窗口枚举需要 Apple Events；若系统拒绝自动化权限，则安全回退到 NSWorkspace.open。
@MainActor
final class FinderWindowService {
    enum OpenResult {
        case reusedExistingWindow
        case openedDirectory
        case invalidPath
    }

    @discardableResult
    func openDirectory(_ rawPath: String) -> OpenResult {
        let expanded = NSString(string: rawPath).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            NSSound.beep()
            return .invalidPath
        }

        if activateExistingFinderWindow(for: url) {
            return .reusedExistingWindow
        }

        NSWorkspace.shared.open(url)
        return .openedDirectory
    }

    /// 返回 true 表示已找到同一路径窗口并激活；false 时调用方再新开目录。
    private func activateExistingFinderWindow(for url: URL) -> Bool {
        let escapedPath = appleScriptString(url.path)
        let source = """
        tell application "Finder"
            set targetPath to POSIX file "\(escapedPath)" as alias
            repeat with w in Finder windows
                try
                    if (target of w as alias) is targetPath then
                        set index of w to 1
                        set collapsed of w to false
                        activate
                        return "FOUND"
                    end if
                end try
            end repeat
            return "NOT_FOUND"
        end tell
        """
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return false }
        return result.stringValue == "FOUND"
    }

    private func appleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
#endif

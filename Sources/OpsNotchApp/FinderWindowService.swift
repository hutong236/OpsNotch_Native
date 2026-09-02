#if os(macOS)
import AppKit
import Foundation

/// 打开 Finder 目录时优先复用已经展示同一路径的 Finder 窗口。
/// “优先 Tab”模式会通过 Finder + System Events 创建新标签页；若自动化/辅助功能权限不可用，
/// 则安全回退到 NSWorkspace.open，确保目录仍然可以打开。
@MainActor
final class FinderWindowService {
    enum OpenResult {
        case reusedExistingWindow
        case openedTab
        case openedDirectory
        case openedDirectoryAfterTabFallback
        case invalidPath
    }

    private enum TabOpenResult {
        case opened
        case noExistingWindow
        case failed
    }

    @discardableResult
    func openDirectory(_ rawPath: String, mode: FinderOpenMode = .preferTab) -> OpenResult {
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

        if mode == .preferTab {
            switch openInExistingFinderTab(url) {
            case .opened:
                return .openedTab
            case .noExistingWindow:
                NSWorkspace.shared.open(url)
                return .openedDirectory
            case .failed:
                NSWorkspace.shared.open(url)
                return .openedDirectoryAfterTabFallback
            }
        }

        NSWorkspace.shared.open(url)
        return .openedDirectory
    }

    /// 返回 true 表示已找到同一路径窗口并激活；false 时调用方再按配置决定新 Tab 或默认打开。
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

    /// Finder 已有窗口时，用 ⌘T 创建新标签页，再把活动标签页切到目标目录。
    /// 该行为依赖 System Events UI scripting，因此可能需要“自动化/辅助功能”权限。
    private func openInExistingFinderTab(_ url: URL) -> TabOpenResult {
        let escapedPath = appleScriptString(url.path)
        let source = """
        tell application "Finder"
            if (count of Finder windows) is 0 then return "NO_WINDOW"
            activate
        end tell

        delay 0.08

        tell application "System Events"
            keystroke "t" using command down
        end tell

        delay 0.08

        tell application "Finder"
            set targetPath to POSIX file "\(escapedPath)" as alias
            set target of front Finder window to targetPath
            set collapsed of front Finder window to false
            activate
        end tell

        return "OPENED_TAB"
        """

        guard let script = NSAppleScript(source: source) else { return .failed }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return .failed }

        switch result.stringValue {
        case "OPENED_TAB": return .opened
        case "NO_WINDOW": return .noExistingWindow
        default: return .failed
        }
    }

    private func appleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
#endif

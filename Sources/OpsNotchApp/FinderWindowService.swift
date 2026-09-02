#if os(macOS)
import AppKit
import Foundation

/// Finder 目录打开服务。
/// AppleScript/UI scripting 始终在独立 osascript 进程中执行并带超时，避免 Finder、权限弹窗或
/// System Events 异常时阻塞 Ops Notch 主线程。
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
    func openDirectory(_ rawPath: String, mode: FinderOpenMode = .systemDefault) async -> OpenResult {
        let expanded = NSString(string: rawPath).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            NSSound.beep()
            return .invalidPath
        }

        if await activateExistingFinderWindow(for: url) {
            return .reusedExistingWindow
        }

        if mode == .preferTab {
            switch await openInExistingFinderTab(url) {
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

    /// 同路径复用也通过独立 osascript 执行；最多等待 1.2 秒。
    private func activateExistingFinderWindow(for url: URL) async -> Bool {
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
        return await FinderAppleScriptRunner.run(source, timeout: 1.2) == "FOUND"
    }

    /// Finder 已有窗口时，尝试通过 ⌘T 创建新标签页，再把活动标签页切到目标目录。
    /// UI scripting 最多执行 1.5 秒；失败、权限拒绝或超时均立即回退。
    private func openInExistingFinderTab(_ url: URL) async -> TabOpenResult {
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

        switch await FinderAppleScriptRunner.run(source, timeout: 1.5) {
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

/// 将不稳定的 Apple Events / UI scripting 隔离在子进程里。
/// 即使 Finder 或 System Events 不响应，超时后也只终止 osascript，不阻塞 AppKit 主线程。
private enum FinderAppleScriptRunner {
    static func run(_ source: String, timeout: TimeInterval) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let standardOutput = Pipe()
                let standardError = Pipe()
                let finished = DispatchSemaphore(value: 0)

                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", source]
                process.standardOutput = standardOutput
                process.standardError = standardError
                process.terminationHandler = { _ in finished.signal() }

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }

                let milliseconds = max(100, Int(timeout * 1_000))
                if finished.wait(timeout: .now() + .milliseconds(milliseconds)) == .timedOut {
                    process.terminate()
                    continuation.resume(returning: nil)
                    return
                }

                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                let data = standardOutput.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: output)
            }
        }
    }
}
#endif

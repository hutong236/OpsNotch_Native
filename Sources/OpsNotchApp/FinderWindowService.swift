#if os(macOS)
import AppKit
import Foundation

/// Finder 目录打开服务。
/// 默认模式直接使用 NSWorkspace，避免 AppleScript 进程启动和窗口扫描延迟；仅优先 Tab 模式
/// 使用带超时的独立 osascript 进程，避免 Finder、权限弹窗或 System Events 阻塞主线程。
@MainActor
final class FinderWindowService {
    enum OpenResult {
        case reusedExistingWindow
        case openedTab
        case openedDirectory
        case openedDirectoryAfterTabFallback
        case invalidPath
    }

    private enum PreferredTabOpenResult {
        case reusedExistingWindow
        case openedTab
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

        // 高频默认路径必须是零自动化的直达路径。此前这里会先启动 osascript 扫描窗口，
        // 即使用户选择系统默认模式也可能额外等待最多 1.2 秒。
        guard mode == .preferTab else {
            NSWorkspace.shared.open(url)
            return .openedDirectory
        }

        switch await openPreferredFinderTab(url) {
        case .reusedExistingWindow:
            return .reusedExistingWindow
        case .openedTab:
            return .openedTab
        case .noExistingWindow:
            NSWorkspace.shared.open(url)
            return .openedDirectory
        case .failed:
            NSWorkspace.shared.open(url)
            return .openedDirectoryAfterTabFallback
        }
    }

    /// 一次自动化调用内完成“复用同路径窗口”与“新建 Tab”，避免连续启动两个 osascript。
    /// 整条 UI scripting 链路最多执行 1.5 秒；失败、权限拒绝或超时均立即回退。
    private func openPreferredFinderTab(_ url: URL) async -> PreferredTabOpenResult {
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
                        return "REUSED_WINDOW"
                    end if
                end try
            end repeat

            if (count of Finder windows) is 0 then return "NO_WINDOW"
            activate
        end tell

        delay 0.05

        tell application "System Events"
            keystroke "t" using command down
        end tell

        delay 0.05

        tell application "Finder"
            set target of front Finder window to targetPath
            set collapsed of front Finder window to false
            activate
        end tell

        return "OPENED_TAB"
        """

        switch await FinderAppleScriptRunner.run(source, timeout: 1.5) {
        case "REUSED_WINDOW": return .reusedExistingWindow
        case "OPENED_TAB": return .openedTab
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

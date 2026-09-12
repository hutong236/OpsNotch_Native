#if os(macOS)
import AppKit
import Foundation

/// 管理 Quick Shelf 的临时键盘焦点会话。
///
/// Shelf 使用 `.nonactivatingPanel`，因此不应该真正激活 Ops Notch；但展开态为了支持
/// 搜索、方向键和 Enter 会成为 key window。该协调器记录当时仍处于前台的原应用，
/// 并在 Shelf 收起后以协作式 activation 让原应用重新建立 key window / first responder。
///
/// 如果用户在 Shelf 打开期间主动切换到了其他应用，则放弃恢复，避免抢焦点。
@MainActor
final class FocusReturnCoordinator {
    private let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
    private var previousApplication: NSRunningApplication?
    private var didBecomeKeyObserver: NSObjectProtocol?
    private var didResignKeyObserver: NSObjectProtocol?

    init() {
        didBecomeKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let panel = notification.object as? ShelfPanel else { return }
            Task { @MainActor [weak self, weak panel] in
                guard let self, let panel else { return }
                self.captureFrontmostApplication(for: panel)
            }
        }

        didResignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let panel = notification.object as? ShelfPanel else { return }
            Task { @MainActor [weak self, weak panel] in
                // ShelfWindowController 也会响应 didResignKey 并执行 orderOut。
                // 给它一个极短的主线程窗口完成隐藏，再判断最终可见性；10ms 对交互不可感知。
                try? await Task.sleep(nanoseconds: 10_000_000)
                guard let self, let panel else { return }
                self.handlePanelResignedKey(panel)
            }
        }
    }

    deinit {
        if let didBecomeKeyObserver {
            NotificationCenter.default.removeObserver(didBecomeKeyObserver)
        }
        if let didResignKeyObserver {
            NotificationCenter.default.removeObserver(didResignKeyObserver)
        }
    }

    /// A desktop command owns focus from now on. Do not activate the source
    /// app from the delayed Shelf resign-key callback after it has moved away.
    func discardSession() {
        previousApplication = nil
    }

    private func captureFrontmostApplication(for panel: ShelfPanel) {
        guard panel.isVisible,
              let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ownProcessIdentifier else { return }
        previousApplication = application
    }

    private func handlePanelResignedKey(_ panel: ShelfPanel) {
        guard let previousApplication else { return }

        if previousApplication.isTerminated {
            self.previousApplication = nil
            return
        }

        let currentApplication = NSWorkspace.shared.frontmostApplication

        // Panel 仍可见时通常是 sheet/menu 临时拿走 key；不恢复。
        // 如果此时前台已经变成另一个第三方应用，则说明用户主动切换，结束旧会话。
        if panel.isVisible {
            if let currentApplication,
               currentApplication.processIdentifier != ownProcessIdentifier,
               currentApplication.processIdentifier != previousApplication.processIdentifier {
                self.previousApplication = nil
            }
            return
        }

        // Shelf 已收起。只有原应用仍然是前台时才发起 activation 请求。
        // 若当前是其他应用（包括 Ops Notch 自己的设置/文件面板），绝不抢回旧焦点。
        self.previousApplication = nil
        guard let currentApplication,
              currentApplication.processIdentifier == previousApplication.processIdentifier else { return }

        _ = previousApplication.activate(options: [])
    }
}
#endif

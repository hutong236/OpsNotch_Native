#if os(macOS)
import AppKit
import SwiftUI

/// Pure geometry policy used by Settings presentation and unit tests.
/// A tiny sliver on a removed/rearranged display is not considered meaningfully visible.
enum SettingsWindowVisibilityPolicy {
    private static let minimumVisibleWidth: CGFloat = 120
    private static let minimumVisibleHeight: CGFloat = 80

    static func needsRecentering(windowFrame: NSRect, visibleFrames: [NSRect]) -> Bool {
        guard !visibleFrames.isEmpty else { return false }
        return !visibleFrames.contains { visibleFrame in
            let intersection = NSIntersectionRect(windowFrame, visibleFrame)
            return intersection.width >= minimumVisibleWidth
                && intersection.height >= minimumVisibleHeight
        }
    }
}

@MainActor
final class SettingsWindowController {
    private let model: AppModel
    private let finderReveal: FinderRevealController
    private let inputMethodManager: InputMethodManager
    private let loginItem = LoginItemService()
    private var window: NSWindow?

    init(
        model: AppModel,
        finderReveal: FinderRevealController,
        inputMethodManager: InputMethodManager
    ) {
        self.model = model
        self.finderReveal = finderReveal
        self.inputMethodManager = inputMethodManager
    }

    func show() {
        let window = ensureWindow()
        window.title = L10n.text("settingsTitle", model.language)
        present(window)
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }

        let rootView = SettingsRootView(
            model: model,
            loginItem: loginItem,
            finderReveal: finderReveal,
            inputMethodManager: inputMethodManager
        )
        let hosting = NSHostingView(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text("settingsTitle", model.language)
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 720, height: 520)

        // Settings is a control-center window, not a workspace-bound document.
        // Reopening it from the menu bar should surface it on the Space the user is
        // currently working in instead of silently leaving it on an older desktop.
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()

        self.window = window
        return window
    }

    private func present(_ window: NSWindow) {
        let app = NSApplication.shared

        // Cmd+Q intentionally hides Ops Notch instead of terminating it. A hidden
        // accessory app may otherwise receive the Settings action without surfacing
        // its window, which looks like a dead menu item.
        if app.isHidden {
            app.unhide(nil)
        }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        let screens = NSScreen.screens
        if SettingsWindowVisibilityPolicy.needsRecentering(
            windowFrame: window.frame,
            visibleFrames: screens.map(\.visibleFrame)
        ) {
            center(window, on: preferredScreen(from: screens))
        }

        app.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func preferredScreen(from screens: [NSScreen]) -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
            ?? screens.first
    }

    private func center(_ window: NSWindow, on screen: NSScreen?) {
        guard let screen else {
            window.center()
            return
        }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - window.frame.width / 2,
            y: visible.midY - window.frame.height / 2
        )
        window.setFrameOrigin(origin)
    }
}
#endif

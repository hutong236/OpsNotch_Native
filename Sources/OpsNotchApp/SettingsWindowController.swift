#if os(macOS)
import AppKit
import SwiftUI

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
        if let window {
            window.title = L10n.text("settingsTitle", model.language)
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

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
        window.center()

        self.window = window
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
#endif

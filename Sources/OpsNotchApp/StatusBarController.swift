#if os(macOS)
import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let model: AppModel
    private let shelf: ShelfWindowController
    private let sensors: SensorManager
    private let settings: SettingsWindowController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(model: AppModel, shelf: ShelfWindowController, sensors: SensorManager, settings: SettingsWindowController) {
        self.model = model
        self.shelf = shelf
        self.sensors = sensors
        self.settings = settings
        super.init()
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "tray.full", accessibilityDescription: "Ops Notch")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Ops Notch"
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(item(L10n.text("openShelf", model.language), #selector(openShelf)))
        menu.addItem(item(L10n.text("newText", model.language), #selector(newText)))
        menu.addItem(.separator())
        let versionItem = NSMenuItem(title: "Ops Notch v\(AppVersionService.current)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(.separator())
        menu.addItem(item(L10n.text("settings", model.language) + "…", #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(item(L10n.text("quit", model.language), #selector(quit)))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openShelf() {
        if let screen = sensors.preferredScreen() { shelf.showExpanded(on: screen) }
    }

    @objc private func newText() {
        if let screen = sensors.preferredScreen() { shelf.showExpanded(on: screen) }
        model.editorDraft = .text()
    }

    @objc private func openSettings() { settings.show() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}
#endif

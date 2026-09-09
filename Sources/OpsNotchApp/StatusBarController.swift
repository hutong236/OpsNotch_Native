#if os(macOS)
import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let model: AppModel
    private let shelf: ShelfWindowController
    private let sensors: SensorManager
    private let settings: SettingsWindowController
    private let menuBarManager: MenuBarManager
    private var statusMenu = NSMenu()

    init(
        model: AppModel,
        shelf: ShelfWindowController,
        sensors: SensorManager,
        settings: SettingsWindowController,
        menuBarManager: MenuBarManager
    ) {
        self.model = model
        self.shelf = shelf
        self.sensors = sensors
        self.settings = settings
        self.menuBarManager = menuBarManager
        super.init()

        rebuildMenu()
        menuBarManager.setStatusMenuProvider { [weak self] in
            self?.statusMenu ?? NSMenu()
        }
        menuBarManager.setStatusMenuDidChange { [weak self] in
            self?.rebuildMenu()
        }
    }

    /// 菜单在设置或菜单栏状态变化时预构建，右键展示路径只负责 popUp，避免可感知等待。
    func rebuildMenu() {
        statusMenu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item(L10n.text("openShelf", model.language), #selector(openShelf)))
        menu.addItem(item(L10n.text("newText", model.language), #selector(newText)))
        menu.addItem(.separator())

        menuBarManager.appendManagementItems(to: menu)

        let versionItem = NSMenuItem(title: "Ops Notch v\(AppVersionService.current)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(.separator())
        menu.addItem(item(L10n.text("settings", model.language) + "…", #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(item(L10n.text("quit", model.language), #selector(quit)))
        return menu
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

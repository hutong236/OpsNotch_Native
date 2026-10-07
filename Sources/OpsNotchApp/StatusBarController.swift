#if os(macOS)
import AppKit

enum StatusMenuEntry: Equatable {
    case openShelf
    case keepShelfOpen
    case settings
    case quit
}

@MainActor
final class StatusBarController: NSObject {
    static let menuLayout: [StatusMenuEntry] = [.openShelf, .keepShelfOpen, .settings, .quit]

    private let model: AppModel
    private let shelf: ShelfWindowController
    private let sensors: SensorManager
    private let settings: SettingsWindowController
    private let statusItem: NSStatusItem
    private var statusMenu = NSMenu()

    init(
        model: AppModel,
        shelf: ShelfWindowController,
        sensors: SensorManager,
        settings: SettingsWindowController
    ) {
        self.model = model
        self.shelf = shelf
        self.sensors = sensors
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        cleanupLegacyMenuBarPreferences()
        configureStatusItem()
        rebuildMenu()
    }

    /// 删除已移除的隐藏区分隔条位置记录；保留 control 的位置，使 Ops Notch 图标升级后不跳位。
    private func cleanupLegacyMenuBarPreferences() {
        let legacyAutosaveNames = [
            "lab.hutong.opsnotch.menubar.hidden-separator",
            "lab.hutong.opsnotch.menubar.hidden-spacer-v3",
            "lab.hutong.opsnotch.menubar.always-hidden-separator",
        ]
        for autosaveName in legacyAutosaveNames {
            UserDefaults.standard.removeObject(
                forKey: "NSStatusItem Preferred Position \(autosaveName)"
            )
        }
    }

    /// 菜单在设置变化时重建；状态项仅作为 Ops Notch 的普通菜单栏入口。
    func rebuildMenu() {
        statusMenu = makeMenu()
        statusItem.menu = statusMenu
    }

    private func configureStatusItem() {
        // 复用旧菜单栏管理入口的 autosaveName，升级后尽量保持 Ops Notch 图标原有位置。
        statusItem.autosaveName = "lab.hutong.opsnotch.menubar.control"
        statusItem.isVisible = true
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "tray.full", accessibilityDescription: "Ops Notch")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Ops Notch"
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        for entry in Self.menuLayout {
            switch entry {
            case .openShelf:
                menu.addItem(item(
                    L10n.text("openShelf", model.language),
                    symbolName: "tray.full",
                    action: #selector(openShelf)
                ))
            case .keepShelfOpen:
                let keepOpen = item(
                    L10n.text("keepShelfOpen", model.language),
                    symbolName: "pin",
                    action: #selector(toggleKeepShelfOpen)
                )
                keepOpen.state = model.settings.shelfKeepOpen ? .on : .off
                menu.addItem(keepOpen)
            case .settings:
                menu.addItem(.separator())
                menu.addItem(item(
                    L10n.text("settings", model.language) + "…",
                    symbolName: "gearshape",
                    action: #selector(openSettings)
                ))
            case .quit:
                menu.addItem(.separator())
                menu.addItem(item(
                    L10n.text("quit", model.language),
                    symbolName: "power",
                    action: #selector(quit)
                ))
            }
        }

        return menu
    }

    private func item(_ title: String, symbolName: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = menuImage(symbolName, description: title)
        return item
    }

    private func menuImage(_ symbolName: String, description: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
        image?.isTemplate = true
        return image
    }

    @objc private func openShelf() {
        if let screen = sensors.preferredScreen() { shelf.showExpanded(on: screen) }
    }

    @objc private func toggleKeepShelfOpen() {
        let turningOn = !model.settings.shelfKeepOpen
        model.updateSettings { $0.shelfKeepOpen = turningOn }

        if turningOn {
            if let screen = sensors.preferredScreen() { shelf.showExpanded(on: screen) }
        } else if shelf.isPanelVisible {
            shelf.hide()
        }
    }

    @objc private func openSettings() { settings.show() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}
#endif

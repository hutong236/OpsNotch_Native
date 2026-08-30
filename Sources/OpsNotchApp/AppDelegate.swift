#if os(macOS)
import AppKit
import OpsNotchCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var clipboard: ClipboardManager!
    private var shelf: ShelfWindowController!
    private var sensors: SensorManager!
    private var settingsWindow: SettingsWindowController!
    private var statusBar: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let store = ShelfStoreService(rootURL: ShelfStoreService.defaultRootURL())
        model = AppModel(store: store)
        clipboard = ClipboardManager(model: model)
        shelf = ShelfWindowController(model: model, clipboard: clipboard)
        sensors = SensorManager(model: model, shelf: shelf, clipboard: clipboard)
        settingsWindow = SettingsWindowController(model: model)
        statusBar = StatusBarController(model: model, shelf: shelf, sensors: sensors, settings: settingsWindow)

        model.settingsDidChange = { [weak self] in
            self?.sensors.rebuild()
            self?.statusBar.rebuildMenu()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
#endif

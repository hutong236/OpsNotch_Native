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
    private var hotkey: HotkeyService!
    private var finderReveal: FinderRevealController!
    private var unifiedFinder: UnifiedFinderCoordinator!
    private var inputMethodManager: InputMethodManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let store = ShelfStoreService(rootURL: ShelfStoreService.defaultRootURL())
        model = AppModel(store: store)
        clipboard = ClipboardManager(model: model)
        clipboard.startMonitoring()
        shelf = ShelfWindowController(model: model, clipboard: clipboard)
        sensors = SensorManager(model: model, shelf: shelf, clipboard: clipboard)
        shelf.dropHandler = { [weak sensors] payload in sensors?.handleDrop(payload: payload) ?? false }

        unifiedFinder = UnifiedFinderCoordinator(model: model, shelf: shelf)
        model.requestOpenFinderPath = { [weak unifiedFinder] path, quickPathID in
            unifiedFinder?.open(path: path, quickPathID: quickPathID)
        }

        hotkey = CarbonHotkeyService(id: 1)
        hotkey.onFire = { [weak self] in self?.shelf.toggleSummon() }
        model.hotkeyApply = { [weak hotkey] shortcut in hotkey?.apply(shortcut) }
        hotkey.apply(model.settings.hotkey)

        finderReveal = FinderRevealController(model: model) { [weak self] in
            guard let self else { return }
            if self.shelf.isPanelVisible {
                self.model.highlightFinderDefault()
            } else {
                self.shelf.toggleSummon()
            }
        }
        inputMethodManager = InputMethodManager()
        settingsWindow = SettingsWindowController(
            model: model,
            finderReveal: finderReveal,
            inputMethodManager: inputMethodManager
        )
        statusBar = StatusBarController(model: model, shelf: shelf, sensors: sensors, settings: settingsWindow)

        model.settingsDidChange = { [weak self] in
            guard let self else { return }
            self.sensors.rebuild()
            self.statusBar.rebuildMenu()
            self.hotkey.apply(self.model.settings.hotkey)
            self.finderReveal.syncFromSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboard?.stopMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
#endif

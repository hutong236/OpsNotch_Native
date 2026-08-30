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
    private var lastOpenEventAt: TimeInterval?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let store = ShelfStoreService(rootURL: ShelfStoreService.defaultRootURL())
        model = AppModel(store: store)
        clipboard = ClipboardManager(model: model)
        shelf = ShelfWindowController(model: model, clipboard: clipboard)
        sensors = SensorManager(model: model, shelf: shelf, clipboard: clipboard)
        settingsWindow = SettingsWindowController(model: model)
        statusBar = StatusBarController(model: model, shelf: shelf, sensors: sensors, settings: settingsWindow)

        hotkey = CarbonHotkeyService()
        hotkey.onFire = { [weak self] in self?.shelf.toggleSummon() }
        model.hotkeyApply = { [weak hotkey] shortcut in hotkey?.apply(shortcut) }

        // App Intents 快捷指令入口(聚焦短语):与热键/打开事件共用同一切换语义。
        NotificationCenter.default.addObserver(
            forName: .summonShelfRequested, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.shelf.toggleSummon() }
        }

        model.settingsDidChange = { [weak self] in
            guard let self else { return }
            self.sensors.rebuild()
            self.statusBar.rebuildMenu()
            self.hotkey.apply(self.model.settings.hotkey)
        }
        hotkey.apply(model.settings.hotkey)
    }

    /// 聚焦/Finder/open 命令的"打开应用"事件入口。reopen 仅在应用已在运行时由系统投递,
    /// 冷启动与登录项自启不会到达这里,天然满足"冷启动不自动展开面板"。
    /// 时间窗去抖(激活流程可能连投多次)后复用热键同款切换语义。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        if ShelfLogic.shouldHandleOpenEvent(lastAt: lastOpenEventAt, now: now, window: 0.3) {
            lastOpenEventAt = now
            shelf.toggleSummon()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
#endif

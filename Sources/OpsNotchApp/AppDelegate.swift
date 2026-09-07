#if os(macOS)
import AppKit
import OpsNotchCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var clipboard: ClipboardManager!
    private var shelf: ShelfWindowController!
    private var focusReturn: FocusReturnCoordinator!
    private var sensors: SensorManager!
    private var dragOverlay: DragDropOverlayController!
    private var dragCoordinator: DragSessionCoordinator!
    private var settingsWindow: SettingsWindowController!
    private var statusBar: StatusBarController!
    private var hotkey: HotkeyService!
    private var finderReveal: FinderRevealController!
    private var unifiedFinder: UnifiedFinderCoordinator!
    private var inputMethodManager: InputMethodManager!
    private var desktopCommands: DesktopCommandIntegration!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let store = ShelfStoreService(rootURL: ShelfStoreService.defaultRootURL())
        model = AppModel(store: store)
        desktopCommands = DesktopCommandIntegration(model: model)
        clipboard = ClipboardManager(model: model)
        clipboard.startMonitoring()
        shelf = ShelfWindowController(model: model, clipboard: clipboard)
        // Quick Shelf 会临时成为 key window；集中管理原应用焦点的记录与归还。
        focusReturn = FocusReturnCoordinator()
        desktopCommands.shelf = shelf
        sensors = SensorManager(model: model, shelf: shelf, clipboard: clipboard)
        shelf.dropHandler = { [weak sensors] payload in sensors?.handleDrop(payload: payload) ?? false }

        let promisedFilesHandler: ([URL]) -> Bool = { [weak model] urls in
            guard let model else { return false }
            return model.addPromisedPaths(urls) > 0
        }
        shelf.promisedFilesHandler = promisedFilesHandler

        // Drag Engine V2：外部有效拖拽时主动在鼠标附近提供零权限 Drop Zone。
        dragOverlay = DragDropOverlayController()
        dragCoordinator = DragSessionCoordinator(model: model, shelf: shelf, overlay: dragOverlay)
        dragCoordinator.dropHandler = { [weak sensors] payload in
            sensors?.handleDrop(payload: payload) ?? false
        }
        // File Promise 来源只在 drop 后才生成真实文件，因此统一复制进 Shelf 管理目录，
        // 避免长期引用 drop-staging 临时路径。
        dragCoordinator.promisedFilesHandler = promisedFilesHandler

        // Shelf 可见性 → 各屏 Sensor 指示点 + Drag Assist 目标协调（事件驱动，无轮询）。
        shelf.onVisibilityChange = { [weak self] visible, displayID in
            guard let self else { return }
            self.sensors.setShelfVisible(visible, onDisplayID: displayID)
            self.dragCoordinator.shelfVisibilityDidChange(visible, onDisplayID: displayID)
        }
        dragCoordinator.start()

        // 剪贴板轮询间隔随面板可见性自适应:可见 100ms,不可见 400ms。
        clipboard.panelVisibleProvider = { [weak shelf] in shelf?.isPanelVisible ?? false }

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

        // 常驻展开（图钉）模式：启动后按显示策略直接展开。
        if model.settings.shelfKeepOpen, let screen = sensors.preferredLaunchScreen() {
            shelf.showExpanded(on: screen)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        dragCoordinator?.stop()
        clipboard?.stopMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
#endif

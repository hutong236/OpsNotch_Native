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
    private var menuBarManager: MenuBarManager!
    private var hotkey: HotkeyService!
    private var finderReveal: FinderRevealController!
    private var unifiedFinder: UnifiedFinderCoordinator!
    private var inputMethodManager: InputMethodManager!
    private var desktopCommands: DesktopCommandIntegration!
    private var terminationReplyPending = false
    private var terminationRestorePrepared = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let store = ShelfStoreService(rootURL: ShelfStoreService.defaultRootURL())
        model = AppModel(store: store)
        menuBarManager = MenuBarManager(model: model)
        DragOutLifecycleCoordinator.shared.bind(model: model)
        model.cleanupStaleDragOutRecallStorage()
        DropPayloadResolver.shared.cleanupStaleStaging(rootURL: store.rootURL)

        desktopCommands = DesktopCommandIntegration(model: model)
        clipboard = ClipboardManager(model: model)
        clipboard.startMonitoring()
        shelf = ShelfWindowController(model: model, clipboard: clipboard)
        // Quick Shelf 会临时成为 key window；集中管理原应用焦点的记录与归还。
        focusReturn = FocusReturnCoordinator()
        desktopCommands.shelf = shelf
        sensors = SensorManager(model: model, shelf: shelf, clipboard: clipboard)
        shelf.dropHandler = { [weak sensors] payload in sensors?.handleDrop(payload: payload) ?? false }

        // Promise 与普通 drop 一样通过 SensorManager 汇聚存储语义；Promise 始终复制入受管目录。
        let promisedFilesHandler: ([URL]) -> Bool = { [weak sensors] urls in
            sensors?.handlePromisedDrop(urls: urls) ?? false
        }
        shelf.promisedFilesHandler = promisedFilesHandler

        // Drag Engine V2：外部有效拖拽时主动在鼠标附近提供零权限 Drop Zone。
        dragOverlay = DragDropOverlayController()
        dragCoordinator = DragSessionCoordinator(model: model, shelf: shelf, overlay: dragOverlay)
        dragCoordinator.dropHandler = { [weak sensors] payload in
            sensors?.handleDrop(payload: payload) ?? false
        }
        dragCoordinator.promisedFilesHandler = promisedFilesHandler
        dragCoordinator.onExternalDragActivityChange = { [weak sensors] active in
            sensors?.setExternalDragSessionActive(active)
        }

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
            inputMethodManager: inputMethodManager,
            menuBarManager: menuBarManager
        )
        statusBar = StatusBarController(
            model: model,
            shelf: shelf,
            sensors: sensors,
            settings: settingsWindow,
            menuBarManager: menuBarManager
        )
        menuBarManager.start()

        model.settingsDidChange = { [weak self] in
            guard let self else { return }
            self.sensors.rebuild()
            self.statusBar.rebuildMenu()
            self.hotkey.apply(self.model.settings.hotkey)
            self.finderReveal.syncFromSettings()
            self.menuBarManager.syncFromSettings()
        }

        // 常驻展开（图钉）模式：启动后按显示策略直接展开。
        if model.settings.shelfKeepOpen, let screen = sensors.preferredLaunchScreen() {
            shelf.showExpanded(on: screen)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationReplyPending else { return .terminateLater }
        terminationReplyPending = true
        restoreMenuBarBeforeTermination()

        // 先让 AppKit 完成菜单栏重新布局，再真正结束进程，避免隐藏 Spacer 随进程一起
        // 消失时第三方图标没有机会在当前 runloop 恢复到可见区域。
        DispatchQueue.main.async {
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 正常退出通常已经在 applicationShouldTerminate 中恢复；这里作为注销/关机等
        // 终止路径的幂等兜底，确保 OpsNotch 不把第三方菜单栏图标留在不可见状态。
        restoreMenuBarBeforeTermination()
        menuBarManager?.stop()
        dragCoordinator?.stop()
        clipboard?.stopMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func restoreMenuBarBeforeTermination() {
        guard !terminationRestorePrepared else { return }
        terminationRestorePrepared = true
        guard let model, let menuBarManager else { return }

        // showAll() 会同时释放普通隐藏区与持续隐藏区的 Spacer，并关闭隐藏图标代理面板。
        // 退出恢复只用于当前运行期；恢复完成后写回原来的 lastState，避免改变下次启动偏好。
        let savedLastState = model.settings.menuBarLastState
        menuBarManager.showAll()
        if model.settings.menuBarLastState != savedLastState {
            model.updateSettings(notifyServices: false) { settings in
                settings.menuBarLastState = savedLastState
            }
        }
    }
}
#endif

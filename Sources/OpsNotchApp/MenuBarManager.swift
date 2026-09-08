#if os(macOS)
import AppKit
import Combine
import OpsNotchCore

/// 菜单栏三段管理器。
///
/// 仅通过自己的 NSStatusItem 分隔项改变占位宽度，不读取或修改第三方状态项。
/// 左侧可形成“持续隐藏 / 普通隐藏 / 始终显示”三段；分隔项使用 autosaveName，
/// 用户可按住 ⌘ 拖动它们和其他菜单栏图标来固定区域边界。
@MainActor
final class MenuBarManager: NSObject, ObservableObject {
    @Published private(set) var state: MenuBarVisibilityState = .allExpanded
    @Published var hotkeyConflict = false

    private let model: AppModel
    private let controlItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let hiddenSeparatorItem = NSStatusBar.system.statusItem(withLength: 12)
    private let alwaysHiddenSeparatorItem = NSStatusBar.system.statusItem(withLength: 12)
    private let hotkey: HotkeyService = CarbonHotkeyService(id: 2)

    private var statusMenuProvider: (() -> NSMenu)?
    private var screenObserver: NSObjectProtocol?
    private var autoHideTimer: Timer?
    private var animationTimer: Timer?
    private var managementWasEnabled = false
    private var lastAppliedHotkey: HotkeyShortcut?
    private var rawPanelItems: [String: MenuBarAXScanner.Item] = [:]
    private var panelController: MenuBarHiddenItemsPanelController!

    private let separatorLength: CGFloat = 12
    private let animationDuration: TimeInterval = 0.16

    private enum PositionValidation {
        case valid
        case invalid
        case unavailable
    }

    init(model: AppModel) {
        self.model = model
        super.init()
        configureStatusItems()
        panelController = MenuBarHiddenItemsPanelController(language: model.language)
        panelController.onRefresh = { [weak self] in self?.refreshPanelItems(promptForPermission: false) }
        panelController.onRequestPermission = { [weak self] in self?.refreshPanelItems(promptForPermission: true) }
        panelController.onActivate = { [weak self] id in self?.activatePanelItem(id: id) }
    }

    func start() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenParametersDidChange() }
        }
        syncFromSettings(initial: true)
        // Status item 的 backing window 需要一个 runloop 才稳定；再次应用启动态，避免首次启动时位置尚不可测。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, self.model.settings.menuBarManagementEnabled else { return }
            let desired = self.model.settings.menuBarStartCollapsed
                ? MenuBarVisibilityState.collapsed
                : self.model.settings.menuBarLastState
            self.setState(desired, userInitiated: false, persist: false)
        }
    }

    func stop() {
        autoHideTimer?.invalidate()
        animationTimer?.invalidate()
        autoHideTimer = nil
        animationTimer = nil
        _ = hotkey.apply(nil)
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        panelController?.close()
    }

    func setStatusMenuProvider(_ provider: @escaping () -> NSMenu) {
        statusMenuProvider = provider
    }

    func syncFromSettings(initial: Bool = false) {
        let settings = model.settings
        let enabled = settings.menuBarManagementEnabled
        let enabling = enabled && (!managementWasEnabled || initial)
        managementWasEnabled = enabled

        hiddenSeparatorItem.isVisible = enabled
        alwaysHiddenSeparatorItem.isVisible = enabled && settings.menuBarAlwaysHiddenEnabled
        controlItem.isVisible = true
        hiddenSeparatorItem.length = max(hiddenSeparatorItem.length, separatorLength)
        if !settings.menuBarAlwaysHiddenEnabled {
            alwaysHiddenSeparatorItem.length = separatorLength
        }

        let desiredHotkey = enabled ? settings.menuBarHotkey : nil
        if desiredHotkey != lastAppliedHotkey {
            if hotkey.apply(desiredHotkey) == nil {
                hotkeyConflict = false
                lastAppliedHotkey = desiredHotkey
            } else {
                hotkeyConflict = true
            }
        }

        panelController.language = model.language

        if !enabled {
            applyState(.allExpanded, animated: false, scheduleAutoHide: false)
            return
        }

        if enabling {
            let desired = settings.menuBarStartCollapsed ? .collapsed : settings.menuBarLastState
            setState(desired, userInitiated: false, persist: false)
        } else {
            // 设置变化时保持当前交互状态，只重新计算分隔区宽度与自动收起策略。
            applyState(state, animated: false, scheduleAutoHide: true)
        }
        updateControlAppearance()
    }

    func setHotkey(_ shortcut: HotkeyShortcut?) {
        guard model.settings.menuBarManagementEnabled else { return }
        if hotkey.apply(shortcut) != nil {
            hotkeyConflict = true
            return
        }
        hotkeyConflict = false
        lastAppliedHotkey = shortcut
        model.updateSettings(notifyServices: false) { $0.menuBarHotkey = shortcut }
    }

    func clearHotkeyConflict() {
        hotkeyConflict = false
    }

    func collapse() {
        setState(.collapsed, userInitiated: true)
    }

    func showHiddenArea() {
        setState(.hiddenExpanded, userInitiated: true)
    }

    func showAll() {
        setState(.allExpanded, userInitiated: true)
    }

    func toggleHiddenArea() {
        if state == .collapsed {
            showHiddenArea()
        } else {
            collapse()
        }
    }

    func showHiddenItemsPanel() {
        guard model.settings.menuBarManagementEnabled, model.settings.menuBarPanelEnabled,
              let button = controlItem.button else { return }
        panelController.show(relativeTo: button)
        refreshPanelItems(promptForPermission: false)
    }

    func appendManagementItems(to menu: NSMenu) {
        let enabled = model.settings.menuBarManagementEnabled
        let toggle = NSMenuItem(
            title: L10n.text(enabled ? "menuBarDisable" : "menuBarEnable", model.language),
            action: #selector(toggleEnabledFromMenu),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        guard enabled else {
            menu.addItem(.separator())
            return
        }

        let stateItem = NSMenuItem(
            title: L10n.text(stateKey, model.language),
            action: nil,
            keyEquivalent: ""
        )
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        let hidden = NSMenuItem(
            title: L10n.text(state == .collapsed ? "menuBarShowHidden" : "menuBarCollapse", model.language),
            action: state == .collapsed ? #selector(showHiddenFromMenu) : #selector(collapseFromMenu),
            keyEquivalent: ""
        )
        hidden.target = self
        menu.addItem(hidden)

        if model.settings.menuBarAlwaysHiddenEnabled {
            let all = NSMenuItem(
                title: L10n.text("menuBarShowAll", model.language),
                action: #selector(showAllFromMenu),
                keyEquivalent: ""
            )
            all.target = self
            menu.addItem(all)
        }

        if model.settings.menuBarPanelEnabled {
            let panel = NSMenuItem(
                title: L10n.text("menuBarHiddenPanel", model.language) + "…",
                action: #selector(showPanelFromMenu),
                keyEquivalent: ""
            )
            panel.target = self
            menu.addItem(panel)
        }
        menu.addItem(.separator())
    }

    private var stateKey: String {
        switch state {
        case .collapsed: return "menuBarStateCollapsed"
        case .hiddenExpanded: return "menuBarStateHidden"
        case .allExpanded: return "menuBarStateAll"
        }
    }

    private func configureStatusItems() {
        controlItem.autosaveName = "lab.hutong.opsnotch.menubar.control"
        hiddenSeparatorItem.autosaveName = "lab.hutong.opsnotch.menubar.hidden-separator"
        alwaysHiddenSeparatorItem.autosaveName = "lab.hutong.opsnotch.menubar.always-hidden-separator"

        controlItem.isVisible = true
        hiddenSeparatorItem.isVisible = true
        alwaysHiddenSeparatorItem.isVisible = true

        if let button = controlItem.button {
            button.target = self
            button.action = #selector(controlPressed(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Ops Notch"
        }
        configureSeparator(hiddenSeparatorItem, title: "│", tooltipKey: "menuBarHiddenSeparatorHint")
        configureSeparator(alwaysHiddenSeparatorItem, title: "¦", tooltipKey: "menuBarAlwaysSeparatorHint")
        updateControlAppearance()

        hotkey.onFire = { [weak self] in self?.toggleHiddenArea() }
    }

    private func configureSeparator(_ item: NSStatusItem, title: String, tooltipKey: String) {
        item.length = separatorLength
        guard let button = item.button else { return }
        button.title = title
        button.font = .systemFont(ofSize: 13, weight: .regular)
        button.alignment = .center
        button.toolTip = L10n.text(tooltipKey, model.language)
        button.target = self
        button.action = #selector(separatorPressed(_:))
        button.sendAction(on: [.rightMouseUp])
    }

    @objc private func controlPressed(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu(from: sender)
            return
        }
        guard event.type == .leftMouseUp else { return }

        if !model.settings.menuBarManagementEnabled {
            showContextMenu(from: sender)
        } else if event.modifierFlags.contains(.option) {
            showAll()
        } else if event.modifierFlags.contains(.control), model.settings.menuBarPanelEnabled {
            showHiddenItemsPanel()
        } else {
            toggleHiddenArea()
        }
    }

    @objc private func separatorPressed(_ sender: NSStatusBarButton) {
        showContextMenu(from: sender)
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        guard let menu = statusMenuProvider?() else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 4), in: button)
    }

    @objc private func toggleEnabledFromMenu() {
        model.updateSettings { $0.menuBarManagementEnabled.toggle() }
    }

    @objc private func collapseFromMenu() {
        DispatchQueue.main.async { [weak self] in self?.collapse() }
    }

    @objc private func showHiddenFromMenu() {
        DispatchQueue.main.async { [weak self] in self?.showHiddenArea() }
    }

    @objc private func showAllFromMenu() {
        DispatchQueue.main.async { [weak self] in self?.showAll() }
    }

    @objc private func showPanelFromMenu() {
        DispatchQueue.main.async { [weak self] in self?.showHiddenItemsPanel() }
    }

    private func setState(
        _ newState: MenuBarVisibilityState,
        userInitiated: Bool,
        persist: Bool = true
    ) {
        guard model.settings.menuBarManagementEnabled else {
            applyState(.allExpanded, animated: false, scheduleAutoHide: false)
            return
        }

        if newState != .allExpanded {
            switch positionValidation() {
            case .invalid:
                applyState(.allExpanded, animated: false, scheduleAutoHide: false)
                if userInitiated {
                    presentOrderInvalidAlert()
                }
                return
            case .valid, .unavailable:
                // The backing window can be transiently unavailable while an NSMenu
                // is closing or the menu bar is relaying out. Do not turn that into
                // a silent no-op; apply the requested state and let layout settle.
                break
            }
        }

        applyState(newState, animated: model.settings.menuBarAnimationEnabled, scheduleAutoHide: true)
        if persist, model.settings.menuBarLastState != newState {
            model.updateSettings(notifyServices: false) { $0.menuBarLastState = newState }
        }
    }

    private func applyState(
        _ newState: MenuBarVisibilityState,
        animated: Bool,
        scheduleAutoHide: Bool
    ) {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        state = newState

        let wide = collapsedLength()
        let hiddenTarget: CGFloat
        let alwaysTarget: CGFloat
        switch newState {
        case .collapsed:
            hiddenTarget = wide
            alwaysTarget = separatorLength
        case .hiddenExpanded:
            hiddenTarget = separatorLength
            alwaysTarget = model.settings.menuBarAlwaysHiddenEnabled ? wide : separatorLength
        case .allExpanded:
            hiddenTarget = separatorLength
            alwaysTarget = separatorLength
        }
        setSeparatorLengths(hidden: hiddenTarget, always: alwaysTarget, animated: animated)
        updateControlAppearance()

        if scheduleAutoHide, newState != .collapsed {
            scheduleAutoHideIfNeeded()
        }
    }

    private func setSeparatorLengths(hidden: CGFloat, always: CGFloat, animated: Bool) {
        animationTimer?.invalidate()
        animationTimer = nil

        let hiddenStart = hiddenSeparatorItem.length
        let alwaysStart = alwaysHiddenSeparatorItem.length
        guard animated,
              abs(hiddenStart - hidden) > 0.5 || abs(alwaysStart - always) > 0.5 else {
            hiddenSeparatorItem.length = hidden
            alwaysHiddenSeparatorItem.length = always
            return
        }

        let startedAt = Date()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            MainActor.assumeIsolated {
                let elapsed = Date().timeIntervalSince(startedAt)
                let p = min(max(elapsed / self.animationDuration, 0), 1)
                let eased = 1 - pow(1 - p, 3)
                self.hiddenSeparatorItem.length = hiddenStart + (hidden - hiddenStart) * eased
                self.alwaysHiddenSeparatorItem.length = alwaysStart + (always - alwaysStart) * eased
                if p >= 1 {
                    timer.invalidate()
                    self.animationTimer = nil
                    self.hiddenSeparatorItem.length = hidden
                    self.alwaysHiddenSeparatorItem.length = always
                }
            }
        }
    }

    private func updateControlAppearance() {
        guard let button = controlItem.button else { return }
        let symbol: String
        if !model.settings.menuBarManagementEnabled {
            symbol = "tray.full"
        } else {
            symbol = state == .collapsed ? "tray.full" : "tray.full.fill"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Ops Notch")
        image?.isTemplate = true
        button.image = image
        button.toolTip = L10n.text(stateKey, model.language)
        hiddenSeparatorItem.button?.toolTip = L10n.text("menuBarHiddenSeparatorHint", model.language)
        alwaysHiddenSeparatorItem.button?.toolTip = L10n.text("menuBarAlwaysSeparatorHint", model.language)
    }

    private func collapsedLength() -> CGFloat {
        let widest = NSScreen.screens.map { $0.frame.width }.max() ?? 1728
        return max(500, min(widest * 2, 10_000))
    }

    private func positionsAreValid() -> Bool {
        positionValidation() == .valid
    }

    private func positionValidation() -> PositionValidation {
        guard let controlX = itemX(controlItem),
              let hiddenX = itemX(hiddenSeparatorItem) else {
            return .unavailable
        }

        let rtl = NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft
        let hiddenValid = rtl ? controlX <= hiddenX : controlX >= hiddenX
        guard hiddenValid else { return .invalid }

        guard model.settings.menuBarAlwaysHiddenEnabled else { return .valid }
        guard let alwaysX = itemX(alwaysHiddenSeparatorItem) else { return .unavailable }
        return (rtl ? hiddenX <= alwaysX : hiddenX >= alwaysX) ? .valid : .invalid
    }

    private func presentOrderInvalidAlert() {
        NSSound.beep()
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.text("menuBarOrderInvalid", model.language)
        alert.informativeText = model.language == .zhCN
            ? "按住 ⌘ 拖动菜单栏项目，确保顺序为：持续隐藏 ¦ → 普通隐藏 │ → Ops Notch。调整后再次选择“收起”。"
            : "Hold ⌘ and drag menu bar items so the order is: Always Hidden ¦ → Hidden │ → Ops Notch, then choose Collapse again."
        alert.addButton(withTitle: model.language == .zhCN ? "知道了" : "OK")
        alert.runModal()
    }

    private func itemX(_ item: NSStatusItem) -> CGFloat? {
        item.button?.window?.frame.minX
    }

    private func screenParametersDidChange() {
        guard model.settings.menuBarManagementEnabled else { return }
        applyState(state, animated: false, scheduleAutoHide: true)
    }

    private func scheduleAutoHideIfNeeded() {
        let seconds = model.settings.menuBarAutoHideSeconds
        guard seconds > 0, state != .collapsed else { return }
        autoHideTimer?.invalidate()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: false) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                if self.isMouseInMenuBar || self.panelController.isVisible {
                    self.scheduleAutoHideIfNeeded()
                } else {
                    self.setState(.collapsed, userInitiated: false)
                }
            }
        }
    }

    private var isMouseInMenuBar: Bool {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            mouse.x >= screen.frame.minX && mouse.x <= screen.frame.maxX
                && mouse.y >= screen.visibleFrame.maxY && mouse.y <= screen.frame.maxY
        }
    }

    // MARK: - Optional hidden-item panel

    private func refreshPanelItems(promptForPermission: Bool) {
        panelController.language = model.language
        guard MenuBarAXScanner.ensureTrusted(prompt: promptForPermission) else {
            rawPanelItems.removeAll()
            panelController.setPermissionRequired()
            return
        }
        guard positionsAreValid() else {
            rawPanelItems.removeAll()
            panelController.setUnavailable(L10n.text("menuBarOrderInvalid", model.language))
            return
        }

        panelController.setLoading()
        let previous = state
        applyState(.allExpanded, animated: false, scheduleAutoHide: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            let hiddenX = self.itemX(self.hiddenSeparatorItem)
            let alwaysX = self.model.settings.menuBarAlwaysHiddenEnabled ? self.itemX(self.alwaysHiddenSeparatorItem) : nil
            guard let hiddenX else {
                self.panelController.setUnavailable(L10n.text("menuBarPanelUnavailable", self.model.language))
                self.applyState(previous, animated: false, scheduleAutoHide: true)
                return
            }
            let scanned = MenuBarAXScanner.scan(
                hiddenSeparatorX: hiddenX,
                alwaysHiddenSeparatorX: alwaysX,
                rtl: NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft
            )
            self.rawPanelItems = Dictionary(uniqueKeysWithValues: scanned.map { ($0.id, $0) })
            self.panelController.setItems(scanned.map(\.presentation))
            self.applyState(previous, animated: false, scheduleAutoHide: true)
        }
    }

    private func activatePanelItem(id: String) {
        guard let item = rawPanelItems[id] else { return }
        panelController.close()
        applyState(.allExpanded, animated: model.settings.menuBarAnimationEnabled, scheduleAutoHide: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else { return }
            if !MenuBarAXScanner.activate(item) {
                self.model.showToast(L10n.text("menuBarPanelActivateFailed", self.model.language))
            }
        }
    }
}
#endif

#if os(macOS)
import AppKit
import Combine
import OpsNotchCore

/// 菜单栏三段管理器。
///
/// 仅通过自己的 NSStatusItem host 改变占位宽度，不读取或修改第三方状态项。
/// 左侧可形成“持续隐藏 / 普通隐藏 / 始终显示”三段；隐藏占位与 ‹ / │ 常驻按钮位于同一 Host，
/// Host 变宽时按钮固定在靠 Ops Notch 一侧，因此展开入口不会被一起推走。
@MainActor
final class MenuBarManager: NSObject, ObservableObject {
    @Published private(set) var state: MenuBarVisibilityState = .allExpanded
    @Published var hotkeyConflict = false

    private let model: AppModel
    private let controlItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    // One host item owns both the variable-width hiding spacer and the persistent toggle button.
    // The child toggle is pinned to the edge nearest Ops Notch, so changing host width can never
    // move the user's reveal/collapse control into the hidden side of the menu bar.
    private let hiddenHostItem = NSStatusBar.system.statusItem(withLength: 17)
    private let alwaysHiddenSeparatorItem = NSStatusBar.system.statusItem(withLength: 12)
    private let hotkey: HotkeyService = CarbonHotkeyService(id: 2)

    private var hiddenToggleButton: NSButton?
    private var statusMenuProvider: (() -> NSMenu)?
    private var statusMenuDidChange: (() -> Void)?
    private var screenObserver: NSObjectProtocol?
    private var autoHideTimer: Timer?
    private var animationTimer: Timer?
    private var managementWasEnabled = false
    private var lastAppliedHotkey: HotkeyShortcut?
    private var rawPanelItems: [String: MenuBarAXScanner.Item] = [:]
    private var stagedPanelItems: [String: MenuBarAXScanner.Item] = [:]
    private var panelController: MenuBarHiddenItemsPanelController!
    private var panelOpenedForNotchOverflow = false
    private var notchProbeGeneration = 0
    private var lastPanelScanAt: Date?
    private var panelScanGeneration = 0

    private let separatorLength: CGFloat = 12
    private let hiddenToggleLength: CGFloat = 16
    private let hiddenHostRestingLength: CGFloat = 17
    private let animationDuration: TimeInterval = 0.16
    private let panelCacheLifetime: TimeInterval = 30

    private enum PositionValidation {
        case valid
        case invalid
        case unavailable
    }

    private struct NotchSafeArea {
        let minX: CGFloat
        let maxX: CGFloat
        let rtl: Bool
    }

    init(model: AppModel) {
        self.model = model
        super.init()
        configureStatusItems()
        panelController = MenuBarHiddenItemsPanelController(language: model.language)
        panelController.onRefresh = { [weak self] in self?.refreshPanelItems(promptForPermission: false) }
        panelController.onRequestPermission = { [weak self] in self?.refreshPanelItems(promptForPermission: true) }
        panelController.onInteract = { [weak self] id, interaction in
            self?.interactWithPanelItem(id: id, interaction: interaction)
        }
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

    func setStatusMenuDidChange(_ handler: @escaping () -> Void) {
        statusMenuDidChange = handler
    }

    func syncFromSettings(initial: Bool = false) {
        let settings = model.settings
        let enabled = settings.menuBarManagementEnabled
        let enabling = enabled && (!managementWasEnabled || initial)
        managementWasEnabled = enabled

        hiddenHostItem.isVisible = enabled
        alwaysHiddenSeparatorItem.isVisible = enabled && settings.menuBarAlwaysHiddenEnabled
        controlItem.isVisible = true
        hiddenHostItem.length = max(hiddenHostItem.length, hiddenHostRestingLength)
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
        showNotchAware(.hiddenExpanded)
    }

    func showAll() {
        showNotchAware(.allExpanded)
    }

    private func showNotchAware(_ target: MenuBarVisibilityState) {
        guard model.settings.menuBarManagementEnabled,
              model.settings.menuBarPanelEnabled,
              let safeArea = notchSafeArea() else {
            setState(target, userInitiated: true)
            return
        }

        switch positionValidation() {
        case .invalid, .unavailable:
            setState(target, userInitiated: true)
            return
        case .valid:
            break
        }

        // Notch overflow protection is an advanced path. Basic menu-bar hiding remains
        // permission-free; only users who enabled the hidden-items panel enter this path.
        guard MenuBarAXScanner.ensureTrusted(prompt: false) else {
            panelOpenedForNotchOverflow = true
            applyState(.collapsed, animated: model.settings.menuBarAnimationEnabled, scheduleAutoHide: false)
            panelController.language = model.language
            panelController.setPermissionRequired()
            if let button = controlItem.button {
                panelController.show(relativeTo: button)
            }
            return
        }

        notchProbeGeneration += 1
        let generation = notchProbeGeneration
        applyState(target, animated: false, scheduleAutoHide: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            guard let self, generation == self.notchProbeGeneration else { return }
            self.finishNotchProbe(target: target, safeArea: safeArea)
        }
    }

    private func finishNotchProbe(target: MenuBarVisibilityState, safeArea: NotchSafeArea) {
        guard let hiddenX = hiddenBoundaryX(hiddenHostItem, rtl: safeArea.rtl) else {
            applyState(target, animated: model.settings.menuBarAnimationEnabled, scheduleAutoHide: true)
            persistVisibleState(target)
            return
        }

        let alwaysX = model.settings.menuBarAlwaysHiddenEnabled
            ? hiddenBoundaryX(alwaysHiddenSeparatorItem, rtl: safeArea.rtl)
            : nil
        let scanned = MenuBarAXScanner.scan(
            hiddenSeparatorX: hiddenX,
            alwaysHiddenSeparatorX: alwaysX,
            rtl: safeArea.rtl
        )
        let relevant = scanned.filter { item in
            target == .allExpanded || item.section == .hidden
        }
        let safetyMargin: CGFloat = 6
        let overflow = relevant.contains { item in
            if safeArea.rtl {
                return item.frame.maxX > safeArea.maxX - safetyMargin
            }
            return item.frame.minX < safeArea.minX + safetyMargin
        }

        guard overflow else {
            panelOpenedForNotchOverflow = false
            applyState(target, animated: model.settings.menuBarAnimationEnabled, scheduleAutoHide: true)
            persistVisibleState(target)
            return
        }

        rawPanelItems = Dictionary(uniqueKeysWithValues: relevant.map { ($0.id, $0) })
        lastPanelScanAt = Date()
        panelController.language = model.language
        panelController.setItems(relevant.map(\.presentation))
        panelOpenedForNotchOverflow = true
        applyState(.collapsed, animated: model.settings.menuBarAnimationEnabled, scheduleAutoHide: false)
        if let button = controlItem.button {
            panelController.show(relativeTo: button)
        }
    }

    private func persistVisibleState(_ target: MenuBarVisibilityState) {
        guard model.settings.menuBarLastState != target else { return }
        model.updateSettings(notifyServices: false) { $0.menuBarLastState = target }
    }

    private func notchSafeArea() -> NotchSafeArea? {
        guard let screen = controlItem.button?.window?.screen ?? NSScreen.main else { return nil }
        let rtl = NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft
        if rtl {
            guard let area = screen.auxiliaryTopLeftArea, area.width > 0 else { return nil }
            return NotchSafeArea(minX: area.minX, maxX: area.maxX, rtl: true)
        }
        guard let area = screen.auxiliaryTopRightArea, area.width > 0 else { return nil }
        return NotchSafeArea(minX: area.minX, maxX: area.maxX, rtl: false)
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
        panelOpenedForNotchOverflow = false
        panelController.show(relativeTo: button)

        if !rawPanelItems.isEmpty,
           let lastPanelScanAt,
           Date().timeIntervalSince(lastPanelScanAt) < panelCacheLifetime {
            return
        }
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
        // Keep the legacy hidden-separator autosave key on the combined host so upgrades retain
        // the user's established boundary next to Ops Notch.
        hiddenHostItem.autosaveName = "lab.hutong.opsnotch.menubar.hidden-separator"
        alwaysHiddenSeparatorItem.autosaveName = "lab.hutong.opsnotch.menubar.always-hidden-separator"

        controlItem.isVisible = true
        hiddenHostItem.isVisible = true
        alwaysHiddenSeparatorItem.isVisible = true

        if let button = controlItem.button {
            button.target = self
            button.action = #selector(controlPressed(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Ops Notch"
        }
        configureHiddenHost()
        configureSeparator(alwaysHiddenSeparatorItem, title: "¦", tooltipKey: "menuBarAlwaysSeparatorHint")
        updateControlAppearance()

        hotkey.onFire = { [weak self] in self?.toggleHiddenArea() }
    }

    private func configureHiddenHost() {
        hiddenHostItem.length = hiddenHostRestingLength
        guard let hostButton = hiddenHostItem.button else { return }
        hostButton.title = ""
        hostButton.image = nil
        hostButton.toolTip = nil
        hostButton.target = nil
        hostButton.action = nil
        hostButton.isBordered = false

        let toggle = NSButton(title: "│", target: self, action: #selector(hiddenTogglePressed(_:)))
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.isBordered = false
        toggle.setButtonType(.momentaryPushIn)
        toggle.font = .systemFont(ofSize: 13, weight: .regular)
        toggle.alignment = .center
        toggle.toolTip = L10n.text("menuBarHiddenSeparatorHint", model.language)
        toggle.sendAction(on: [.leftMouseUp, .rightMouseUp])
        hostButton.addSubview(toggle)

        let rtl = NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft
        let horizontalConstraint = rtl
            ? toggle.leadingAnchor.constraint(equalTo: hostButton.leadingAnchor)
            : toggle.trailingAnchor.constraint(equalTo: hostButton.trailingAnchor)
        NSLayoutConstraint.activate([
            horizontalConstraint,
            toggle.topAnchor.constraint(equalTo: hostButton.topAnchor),
            toggle.bottomAnchor.constraint(equalTo: hostButton.bottomAnchor),
            toggle.widthAnchor.constraint(equalToConstant: hiddenToggleLength),
        ])
        hiddenToggleButton = toggle
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
        } else if model.settings.menuBarPanelEnabled {
            // Left-clicking the Ops Notch icon is now a pure panel action. It must never expand
            // the underlying system menu-bar area as a side effect.
            showHiddenItemsPanel()
        } else {
            showContextMenu(from: sender)
        }
    }

    @objc private func hiddenTogglePressed(_ sender: NSButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .leftMouseUp {
            toggleHiddenArea()
            return
        }
        if event.type == .rightMouseUp, let hostButton = hiddenHostItem.button {
            showContextMenu(from: hostButton)
        }
    }

    @objc private func separatorPressed(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu(from: sender)
        }
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
        let stateChanged = state != newState
        state = newState

        let wide = collapsedLength()
        let hiddenTarget: CGFloat
        let alwaysTarget: CGFloat
        switch newState {
        case .collapsed:
            // Host includes the fixed toggle at the visible edge; add its width so the hiding
            // spacer retains the same effective reach as before the host refactor.
            hiddenTarget = wide + hiddenToggleLength
            alwaysTarget = separatorLength
        case .hiddenExpanded:
            hiddenTarget = hiddenHostRestingLength
            alwaysTarget = model.settings.menuBarAlwaysHiddenEnabled ? wide : separatorLength
        case .allExpanded:
            hiddenTarget = hiddenHostRestingLength
            alwaysTarget = separatorLength
        }
        setHostLengths(hidden: hiddenTarget, always: alwaysTarget, animated: animated)
        updateControlAppearance()

        if stateChanged {
            statusMenuDidChange?()
        }

        if scheduleAutoHide, newState != .collapsed {
            scheduleAutoHideIfNeeded()
        }
    }

    private func setHostLengths(hidden: CGFloat, always: CGFloat, animated: Bool) {
        animationTimer?.invalidate()
        animationTimer = nil

        let hiddenStart = hiddenHostItem.length
        let alwaysStart = alwaysHiddenSeparatorItem.length
        guard animated,
              abs(hiddenStart - hidden) > 0.5 || abs(alwaysStart - always) > 0.5 else {
            hiddenHostItem.length = hidden
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
                self.hiddenHostItem.length = hiddenStart + (hidden - hiddenStart) * eased
                self.alwaysHiddenSeparatorItem.length = alwaysStart + (always - alwaysStart) * eased
                if p >= 1 {
                    timer.invalidate()
                    self.animationTimer = nil
                    self.hiddenHostItem.length = hidden
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
        // The toggle is a fixed child view pinned to the host's visible edge. The host itself can
        // grow thousands of points toward the hidden side without moving this button away.
        hiddenToggleButton?.title = state == .collapsed ? "‹" : "│"
        hiddenToggleButton?.toolTip = L10n.text("menuBarHiddenSeparatorHint", model.language)
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
        let rtl = NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft
        guard let controlX = orderAnchorX(controlItem, rtl: rtl),
              let hostX = orderAnchorX(hiddenHostItem, rtl: rtl) else {
            return .unavailable
        }

        // Expected visual order on LTR menu bars:
        // Always Hidden ¦ → combined hidden host [spacer + ‹/│] → Ops Notch.
        let hostValid = rtl ? controlX <= hostX : controlX >= hostX
        guard hostValid else { return .invalid }

        guard model.settings.menuBarAlwaysHiddenEnabled else { return .valid }
        guard let alwaysX = orderAnchorX(alwaysHiddenSeparatorItem, rtl: rtl) else { return .unavailable }
        return (rtl ? hostX <= alwaysX : hostX >= alwaysX) ? .valid : .invalid
    }

    private func presentOrderInvalidAlert() {
        NSSound.beep()
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.text("menuBarOrderInvalid", model.language)
        alert.informativeText = model.language == .zhCN
            ? "按住 ⌘ 拖动可见菜单栏项目，确保顺序为：持续隐藏 ¦ → ‹/│ → Ops Notch。隐藏占位已集成在 ‹/│ 控件内部。调整后再次选择“收起”。"
            : "Hold ⌘ and arrange the visible controls as: Always Hidden ¦ → ‹/│ → Ops Notch. The hiding spacer is integrated into the ‹/│ host. Then choose Collapse again."
        alert.addButton(withTitle: model.language == .zhCN ? "知道了" : "OK")
        alert.runModal()
    }

    private func orderAnchorX(_ item: NSStatusItem, rtl: Bool) -> CGFloat? {
        guard let frame = item.button?.window?.frame else { return nil }
        // Use the edge nearest the next always-visible item. Unlike minX/midX, this remains stable
        // while a spacer grows toward the hidden side of the menu bar.
        return rtl ? frame.minX : frame.maxX
    }

    private func hiddenBoundaryX(_ item: NSStatusItem, rtl: Bool) -> CGFloat? {
        guard let frame = item.button?.window?.frame else { return nil }
        // Hidden items sit on the outer side of the spacer: left on LTR, right on RTL.
        return rtl ? frame.maxX : frame.minX
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
        panelScanGeneration += 1
        let generation = panelScanGeneration
        panelController.language = model.language
        guard MenuBarAXScanner.ensureTrusted(prompt: promptForPermission) else {
            stagedPanelItems.removeAll()
            rawPanelItems.removeAll()
            lastPanelScanAt = nil
            panelController.setPermissionRequired()
            return
        }
        guard positionsAreValid() else {
            stagedPanelItems.removeAll()
            rawPanelItems.removeAll()
            lastPanelScanAt = nil
            panelController.setUnavailable(L10n.text("menuBarOrderInvalid", model.language))
            return
        }

        stagedPanelItems.removeAll(keepingCapacity: true)
        let hadCachedItems = !rawPanelItems.isEmpty
        panelController.beginRefresh(preserveItems: hadCachedItems)
        let scanLayoutState = state

        // AX can inspect menu-extra elements while their status items are displaced by our spacer.
        // Never expand the real system menu bar just to populate the proxy panel.
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  generation == self.panelScanGeneration,
                  scanLayoutState == self.state else { return }
            let rtl = NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft
            let hiddenX = self.hiddenBoundaryX(self.hiddenHostItem, rtl: rtl)
            let alwaysX = self.model.settings.menuBarAlwaysHiddenEnabled
                ? self.hiddenBoundaryX(self.alwaysHiddenSeparatorItem, rtl: rtl)
                : nil
            guard let hiddenX else {
                self.panelScanGeneration += 1
                self.panelController.setUnavailable(L10n.text("menuBarPanelUnavailable", self.model.language))
                return
            }

            MenuBarAXScanner.scanProgressively(
                hiddenSeparatorX: hiddenX,
                alwaysHiddenSeparatorX: alwaysX,
                rtl: rtl,
                onBatch: { [weak self] batch in
                    guard let self, generation == self.panelScanGeneration else { return }
                    for item in batch {
                        self.stagedPanelItems[item.id] = item
                        self.rawPanelItems[item.id] = item
                    }
                    let visible = MenuBarAXScanner.sortedItems(Array(self.rawPanelItems.values))
                    self.lastPanelScanAt = Date()
                    self.panelController.setItems(visible.map(\.presentation), refreshing: true)
                },
                completion: { [weak self] in
                    guard let self, generation == self.panelScanGeneration else { return }
                    let fresh = MenuBarAXScanner.sortedItems(Array(self.stagedPanelItems.values))
                    if !fresh.isEmpty || !hadCachedItems {
                        self.rawPanelItems = Dictionary(uniqueKeysWithValues: fresh.map { ($0.id, $0) })
                    }
                    self.lastPanelScanAt = Date()
                    self.panelScanGeneration += 1
                    let visible = MenuBarAXScanner.sortedItems(Array(self.rawPanelItems.values))
                    self.panelController.setItems(visible.map(\.presentation), refreshing: false)
                }
            )

            // AX calls cannot be cancelled reliably. The UI therefore owns the overall deadline:
            // after two seconds we stop waiting, preserve any partial/cached items, and invalidate
            // this generation so late results cannot overwrite a newer refresh.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self, generation == self.panelScanGeneration else { return }
                self.panelScanGeneration += 1
                let partial = MenuBarAXScanner.sortedItems(Array(self.stagedPanelItems.values))
                if !partial.isEmpty {
                    for item in partial {
                        self.rawPanelItems[item.id] = item
                    }
                    self.lastPanelScanAt = Date()
                    let visible = MenuBarAXScanner.sortedItems(Array(self.rawPanelItems.values))
                    self.panelController.setItems(visible.map(\.presentation), refreshing: false)
                } else if !self.rawPanelItems.isEmpty {
                    self.panelController.finishRefresh()
                } else {
                    self.lastPanelScanAt = nil
                    self.panelController.setUnavailable(L10n.text("menuBarPanelUnavailable", self.model.language))
                }
            }
        }
    }

    private func interactWithPanelItem(id: String, interaction: MenuBarPanelInteraction) {
        guard let item = rawPanelItems[id] else { return }
        panelOpenedForNotchOverflow = false
        if !MenuBarAXScanner.perform(interaction, on: item) {
            model.showToast(L10n.text("menuBarPanelActivateFailed", model.language))
        }
    }
}
#endif

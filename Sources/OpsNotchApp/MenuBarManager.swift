#if os(macOS)
import AppKit
import Combine
import OpsNotchCore

/// 菜单栏三段管理器。
///
/// 仅通过自己的 NSStatusItem spacer 改变占位宽度，不读取或修改第三方状态项。
/// 左侧可形成“持续隐藏 / 普通隐藏 / 始终显示”三段；隐藏 spacer 与 ‹ / │ 常驻 toggle
/// 使用独立 NSStatusItem，保证隐藏几何永远不会把用户的展开入口一起推走。
@MainActor
final class MenuBarManager: NSObject, ObservableObject {
    @Published private(set) var state: MenuBarVisibilityState = .allExpanded
    @Published var hotkeyConflict = false

    private static let controlAutosaveName = "lab.hutong.opsnotch.menubar.control"
    // Reuse the legacy visible boundary identity for the fixed toggle so upgrades keep the
    // user's established location. The spacer deliberately uses a fresh v3 identity because
    // the first two-item experiment may have left a stale hidden-spacer preferred position.
    private static let hiddenToggleAutosaveName = "lab.hutong.opsnotch.menubar.hidden-separator"
    private static let hiddenSpacerAutosaveName = "lab.hutong.opsnotch.menubar.hidden-spacer-v3"
    private static let alwaysHiddenAutosaveName = "lab.hutong.opsnotch.menubar.always-hidden-separator"

    private static func preferredPositionKey(for autosaveName: String) -> String {
        "NSStatusItem Preferred Position \(autosaveName)"
    }

    private static func preferredPosition(for autosaveName: String) -> CGFloat? {
        UserDefaults.standard.object(forKey: preferredPositionKey(for: autosaveName)) as? CGFloat
    }

    private static func setPreferredPosition(_ position: CGFloat, for autosaveName: String) {
        UserDefaults.standard.set(position, forKey: preferredPositionKey(for: autosaveName))
    }

    private static func nextPreferredPosition(after autosaveName: String, fallback: CGFloat) -> CGFloat {
        (preferredPosition(for: autosaveName) ?? fallback - 1) + 1
    }

    /// macOS restores an autosaved status-item position when the item is created. Establish our
    /// default order before creation instead of relying on creation order alone (which is not
    /// stable across relaunches/upgrades once autosave data exists).
    private static func makeStatusItem(
        withLength length: CGFloat,
        autosaveName: String,
        defaultPreferredPosition: CGFloat
    ) -> NSStatusItem {
        if preferredPosition(for: autosaveName) == nil {
            setPreferredPosition(defaultPreferredPosition, for: autosaveName)
        }
        let item = NSStatusBar.system.statusItem(withLength: length)
        item.autosaveName = autosaveName
        return item
    }

    private let model: AppModel
    private let controlItem = MenuBarManager.makeStatusItem(
        withLength: NSStatusItem.squareLength,
        autosaveName: MenuBarManager.controlAutosaveName,
        defaultPreferredPosition: 0
    )
    private let hiddenToggleItem = MenuBarManager.makeStatusItem(
        withLength: 16,
        autosaveName: MenuBarManager.hiddenToggleAutosaveName,
        defaultPreferredPosition: MenuBarManager.nextPreferredPosition(
            after: MenuBarManager.controlAutosaveName,
            fallback: 1
        )
    )
    private var hiddenSpacerItem = MenuBarManager.makeStatusItem(
        withLength: 1,
        autosaveName: MenuBarManager.hiddenSpacerAutosaveName,
        defaultPreferredPosition: MenuBarManager.nextPreferredPosition(
            after: MenuBarManager.hiddenToggleAutosaveName,
            fallback: 2
        )
    )
    private let alwaysHiddenSeparatorItem = MenuBarManager.makeStatusItem(
        withLength: 12,
        autosaveName: MenuBarManager.alwaysHiddenAutosaveName,
        defaultPreferredPosition: MenuBarManager.nextPreferredPosition(
            after: MenuBarManager.hiddenSpacerAutosaveName,
            fallback: 3
        )
    )
    private let hotkey: HotkeyService = CarbonHotkeyService(id: 2)

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
    private let hiddenSpacerRestingLength: CGFloat = 1
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

        setStatusItemVisiblePreservingPosition(hiddenSpacerItem, visible: enabled)
        setStatusItemVisiblePreservingPosition(hiddenToggleItem, visible: enabled)
        setStatusItemVisiblePreservingPosition(
            alwaysHiddenSeparatorItem,
            visible: enabled && settings.menuBarAlwaysHiddenEnabled
        )
        setStatusItemVisiblePreservingPosition(controlItem, visible: true)
        hiddenToggleItem.length = hiddenToggleLength
        hiddenSpacerItem.length = max(hiddenSpacerItem.length, hiddenSpacerRestingLength)
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
        guard let hiddenX = hiddenBoundaryX(hiddenSpacerItem, rtl: safeArea.rtl) else {
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
        // `‹ / │` is a pure real-menu-bar control. In particular, do not call showHiddenArea()
        // here: that API is notch-aware and is allowed to redirect overflow into the proxy panel.
        // The persistent toggle must never open or otherwise mutate the hidden-items panel.
        let target: MenuBarVisibilityState = state == .collapsed ? .hiddenExpanded : .collapsed
        setState(target, userInitiated: true)
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
        controlItem.isVisible = true
        hiddenToggleItem.isVisible = true
        hiddenSpacerItem.isVisible = true
        alwaysHiddenSeparatorItem.isVisible = true

        if let button = controlItem.button {
            button.target = self
            button.action = #selector(controlPressed(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Ops Notch"
        }
        configureHiddenToggle()
        configureHiddenSpacer()
        configureSeparator(alwaysHiddenSeparatorItem, title: "¦", tooltipKey: "menuBarAlwaysSeparatorHint")
        updateControlAppearance()

        hotkey.onFire = { [weak self] in self?.toggleHiddenArea() }
    }

    private func configureHiddenToggle() {
        hiddenToggleItem.length = hiddenToggleLength
        guard let button = hiddenToggleItem.button else { return }
        button.title = "│"
        button.font = .systemFont(ofSize: 13, weight: .regular)
        button.alignment = .center
        button.toolTip = L10n.text("menuBarHiddenSeparatorHint", model.language)
        button.target = self
        button.action = #selector(hiddenTogglePressed(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureHiddenSpacer() {
        hiddenSpacerItem.length = hiddenSpacerRestingLength
        guard let button = hiddenSpacerItem.button else { return }
        button.title = ""
        button.image = nil
        button.toolTip = nil
        button.target = nil
        button.action = nil
        button.isBordered = false
        button.isEnabled = false
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
            // Left-clicking the Ops Notch icon is a pure panel action. It must never expand
            // or collapse the underlying system menu-bar area as a side effect.
            showHiddenItemsPanel()
        } else {
            showContextMenu(from: sender)
        }
    }

    @objc private func hiddenTogglePressed(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .leftMouseUp {
            toggleHiddenArea()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu(from: sender)
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
        // The spacer is internal. If the user Command-dragged the fixed toggle, macOS moves
        // only that visible status item. Reattach the spacer before applying hiding geometry.
        repairHiddenSpacerPositionIfNeeded()
        let stateChanged = state != newState
        state = newState

        let wide = collapsedLength()
        let hiddenTarget: CGFloat
        let alwaysTarget: CGFloat
        switch newState {
        case .collapsed:
            hiddenTarget = wide
            alwaysTarget = separatorLength
        case .hiddenExpanded:
            hiddenTarget = hiddenSpacerRestingLength
            alwaysTarget = model.settings.menuBarAlwaysHiddenEnabled ? wide : separatorLength
        case .allExpanded:
            hiddenTarget = hiddenSpacerRestingLength
            alwaysTarget = separatorLength
        }
        setSpacerLengths(hidden: hiddenTarget, always: alwaysTarget, animated: animated)
        updateControlAppearance()

        if stateChanged {
            statusMenuDidChange?()
        }

        if scheduleAutoHide, newState != .collapsed {
            scheduleAutoHideIfNeeded()
        }
    }

    private func setSpacerLengths(hidden: CGFloat, always: CGFloat, animated: Bool) {
        animationTimer?.invalidate()
        animationTimer = nil

        let hiddenStart = hiddenSpacerItem.length
        let alwaysStart = alwaysHiddenSeparatorItem.length
        hiddenToggleItem.length = hiddenToggleLength
        guard animated,
              abs(hiddenStart - hidden) > 0.5 || abs(alwaysStart - always) > 0.5 else {
            hiddenSpacerItem.length = hidden
            hiddenToggleItem.length = hiddenToggleLength
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
                self.hiddenSpacerItem.length = hiddenStart + (hidden - hiddenStart) * eased
                self.hiddenToggleItem.length = self.hiddenToggleLength
                self.alwaysHiddenSeparatorItem.length = alwaysStart + (always - alwaysStart) * eased
                if p >= 1 {
                    timer.invalidate()
                    self.animationTimer = nil
                    self.hiddenSpacerItem.length = hidden
                    self.hiddenToggleItem.length = self.hiddenToggleLength
                    self.alwaysHiddenSeparatorItem.length = always
                }
            }
        }
    }

    private func updateControlAppearance() {
        // Ops Notch is the hidden-items-panel entry and must not visually mirror real menu-bar
        // expansion state. Keep its identity stable even while `‹ / │` changes between states.
        if let button = controlItem.button {
            let image = NSImage(systemSymbolName: "tray.full", accessibilityDescription: "Ops Notch")
            image?.isTemplate = true
            button.image = image
            button.toolTip = model.settings.menuBarPanelEnabled
                ? "Ops Notch · " + L10n.text("menuBarHiddenPanel", model.language)
                : "Ops Notch"
        }

        // The toggle owns no hiding geometry. Its fixed NSStatusItem length and visibility are
        // independent from the spacer even when the spacer grows thousands of points.
        hiddenToggleItem.length = hiddenToggleLength
        hiddenToggleItem.button?.title = state == .collapsed ? "‹" : "│"
        hiddenToggleItem.button?.toolTip = L10n.text("menuBarHiddenSeparatorHint", model.language)
        alwaysHiddenSeparatorItem.button?.toolTip = L10n.text("menuBarAlwaysSeparatorHint", model.language)
    }

    private func collapsedLength() -> CGFloat {
        let widest = NSScreen.screens.map { $0.frame.width }.max() ?? 1728
        return max(500, min(widest * 2, 10_000))
    }

    /// The fixed toggle is user-draggable, but the 1pt spacer is deliberately invisible.
    /// Keep the spacer immediately on the hidden side of the toggle by following the toggle's
    /// autosaved preferred position. Recreating only the spacer makes AppKit reload that position.
    private func repairHiddenSpacerPositionIfNeeded() {
        guard model.settings.menuBarManagementEnabled,
              let togglePosition = MenuBarManager.preferredPosition(
                  for: MenuBarManager.hiddenToggleAutosaveName
              ) else {
            return
        }

        let desiredPosition = togglePosition + 1
        let currentPosition = MenuBarManager.preferredPosition(
            for: MenuBarManager.hiddenSpacerAutosaveName
        )
        guard currentPosition == nil
                || abs((currentPosition ?? desiredPosition) - desiredPosition) > 0.001 else {
            return
        }

        animationTimer?.invalidate()
        animationTimer = nil
        NSStatusBar.system.removeStatusItem(hiddenSpacerItem)
        MenuBarManager.setPreferredPosition(
            desiredPosition,
            for: MenuBarManager.hiddenSpacerAutosaveName
        )
        hiddenSpacerItem = MenuBarManager.makeStatusItem(
            withLength: hiddenSpacerRestingLength,
            autosaveName: MenuBarManager.hiddenSpacerAutosaveName,
            defaultPreferredPosition: desiredPosition
        )
        configureHiddenSpacer()
        hiddenSpacerItem.isVisible = true
    }

    /// `NSStatusItem.isVisible = false` removes its preferred-position default on macOS. Cache and
    /// restore that value so disabling/re-enabling management cannot scramble our fixed controls.
    private func setStatusItemVisiblePreservingPosition(_ item: NSStatusItem, visible: Bool) {
        guard item.isVisible != visible else { return }
        let autosaveName = item.autosaveName as String
        let cachedPosition = MenuBarManager.preferredPosition(for: autosaveName)
        item.isVisible = visible
        if !visible, let cachedPosition {
            MenuBarManager.setPreferredPosition(cachedPosition, for: autosaveName)
        }
    }

    private func positionsAreValid() -> Bool {
        positionValidation() == .valid
    }

    private func positionValidation() -> PositionValidation {
        let rtl = NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft
        guard let controlX = orderAnchorX(controlItem, rtl: rtl),
              let toggleX = orderAnchorX(hiddenToggleItem, rtl: rtl) else {
            return .unavailable
        }

        // Validate only controls the user can actually Command-drag. The hidden spacer is an
        // internal implementation detail and self-heals from the fixed toggle's saved position.
        let toggleValid = rtl ? controlX <= toggleX : controlX >= toggleX
        guard toggleValid else { return .invalid }

        guard model.settings.menuBarAlwaysHiddenEnabled else { return .valid }
        guard let alwaysX = orderAnchorX(alwaysHiddenSeparatorItem, rtl: rtl) else { return .unavailable }
        return (rtl ? toggleX <= alwaysX : toggleX >= alwaysX) ? .valid : .invalid
    }

    private func presentOrderInvalidAlert() {
        NSSound.beep()
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.text("menuBarOrderInvalid", model.language)
        alert.informativeText = model.language == .zhCN
            ? "按住 ⌘ 只需调整可见菜单栏项目，确保顺序为：持续隐藏 ¦ → 隐藏图标 → ‹/│ → Ops Notch。内部 Spacer 会自动跟随 ‹/│，无需手动处理。调整后再次选择“收起”。"
            : "Hold ⌘ and arrange only the visible controls as: Always Hidden ¦ → hidden items → ‹/│ → Ops Notch. The internal spacer follows ‹/│ automatically. Then choose Collapse again."
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
        repairHiddenSpacerPositionIfNeeded()
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
            let hiddenX = self.hiddenBoundaryX(self.hiddenSpacerItem, rtl: rtl)
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

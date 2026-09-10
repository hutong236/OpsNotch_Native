from pathlib import Path

path = Path('Sources/OpsNotchApp/MenuBarManager.swift')
text = path.read_text()

replacements = []

replacements.append((
'''/// 仅通过自己的 NSStatusItem 分隔项改变占位宽度，不读取或修改第三方状态项。
/// 左侧可形成“持续隐藏 / 普通隐藏 / 始终显示”三段；分隔项使用 autosaveName，
/// 用户可按住 ⌘ 拖动它们和其他菜单栏图标来固定区域边界。''',
'''/// 仅通过自己的 NSStatusItem spacer 改变占位宽度，不读取或修改第三方状态项。
/// 左侧可形成“持续隐藏 / 普通隐藏 / 始终显示”三段；隐藏 spacer 与常驻 toggle 分离，
/// 用户始终可以通过 ‹ / │ 控件展开或收起真实系统菜单栏隐藏区域。'''
))

replacements.append((
'''    private let model: AppModel
    private let controlItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let hiddenSeparatorItem = NSStatusBar.system.statusItem(withLength: 12)
    private let alwaysHiddenSeparatorItem = NSStatusBar.system.statusItem(withLength: 12)
    private let hotkey: HotkeyService = CarbonHotkeyService(id: 2)
''',
'''    private let model: AppModel
    private let controlItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    // AppKit inserts later status items to the left by default. Create toggle before spacer so the
    // new invisible spacer naturally lands immediately to the left of the persistent toggle.
    private let hiddenToggleItem = NSStatusBar.system.statusItem(withLength: 16)
    private let hiddenSpacerItem = NSStatusBar.system.statusItem(withLength: 1)
    private let alwaysHiddenSeparatorItem = NSStatusBar.system.statusItem(withLength: 12)
    private let hotkey: HotkeyService = CarbonHotkeyService(id: 2)
'''
))

replacements.append((
'''    private let separatorLength: CGFloat = 12
    private let animationDuration: TimeInterval = 0.16
''',
'''    private let separatorLength: CGFloat = 12
    private let hiddenToggleLength: CGFloat = 16
    private let hiddenSpacerRestingLength: CGFloat = 1
    private let animationDuration: TimeInterval = 0.16
'''
))

replacements.append((
'''        hiddenSeparatorItem.isVisible = enabled
        alwaysHiddenSeparatorItem.isVisible = enabled && settings.menuBarAlwaysHiddenEnabled
        controlItem.isVisible = true
        hiddenSeparatorItem.length = max(hiddenSeparatorItem.length, separatorLength)
        if !settings.menuBarAlwaysHiddenEnabled {
            alwaysHiddenSeparatorItem.length = separatorLength
        }
''',
'''        hiddenSpacerItem.isVisible = enabled
        hiddenToggleItem.isVisible = enabled
        alwaysHiddenSeparatorItem.isVisible = enabled && settings.menuBarAlwaysHiddenEnabled
        controlItem.isVisible = true
        hiddenToggleItem.length = hiddenToggleLength
        hiddenSpacerItem.length = max(hiddenSpacerItem.length, hiddenSpacerRestingLength)
        if !settings.menuBarAlwaysHiddenEnabled {
            alwaysHiddenSeparatorItem.length = separatorLength
        }
'''
))

replacements.append((
'''    private func finishNotchProbe(target: MenuBarVisibilityState, safeArea: NotchSafeArea) {
        guard let hiddenX = itemX(hiddenSeparatorItem) else {
            applyState(target, animated: model.settings.menuBarAnimationEnabled, scheduleAutoHide: true)
            persistVisibleState(target)
            return
        }

        let alwaysX = model.settings.menuBarAlwaysHiddenEnabled ? itemX(alwaysHiddenSeparatorItem) : nil
''',
'''    private func finishNotchProbe(target: MenuBarVisibilityState, safeArea: NotchSafeArea) {
        guard let hiddenX = hiddenBoundaryX(hiddenSpacerItem, rtl: safeArea.rtl) else {
            applyState(target, animated: model.settings.menuBarAnimationEnabled, scheduleAutoHide: true)
            persistVisibleState(target)
            return
        }

        let alwaysX = model.settings.menuBarAlwaysHiddenEnabled
            ? hiddenBoundaryX(alwaysHiddenSeparatorItem, rtl: safeArea.rtl)
            : nil
'''
))

replacements.append((
'''    private func configureStatusItems() {
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
        // The separator is the dedicated control for revealing/collapsing the real system menu-bar area.
        // Keep the Ops Notch control itself dedicated to the hidden-items proxy panel.
        hiddenSeparatorItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        configureSeparator(alwaysHiddenSeparatorItem, title: "¦", tooltipKey: "menuBarAlwaysSeparatorHint")
        updateControlAppearance()

        hotkey.onFire = { [weak self] in self?.toggleHiddenArea() }
    }

    private func configureSeparator(_ item: NSStatusItem, title: String, tooltipKey: String) {
''',
'''    private func configureStatusItems() {
        controlItem.autosaveName = "lab.hutong.opsnotch.menubar.control"
        // Reuse the old hidden-separator autosave key for the visible toggle so upgrades preserve
        // the user's established boundary position. The new invisible spacer gets its own key.
        hiddenToggleItem.autosaveName = "lab.hutong.opsnotch.menubar.hidden-separator"
        hiddenSpacerItem.autosaveName = "lab.hutong.opsnotch.menubar.hidden-spacer"
        alwaysHiddenSeparatorItem.autosaveName = "lab.hutong.opsnotch.menubar.always-hidden-separator"

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
        configureHiddenSpacer()
        configureHiddenToggle()
        configureSeparator(alwaysHiddenSeparatorItem, title: "¦", tooltipKey: "menuBarAlwaysSeparatorHint")
        updateControlAppearance()

        hotkey.onFire = { [weak self] in self?.toggleHiddenArea() }
    }

    private func configureHiddenSpacer() {
        hiddenSpacerItem.length = hiddenSpacerRestingLength
        guard let button = hiddenSpacerItem.button else { return }
        button.title = ""
        button.image = nil
        button.toolTip = nil
        button.isEnabled = false
    }

    private func configureHiddenToggle() {
        hiddenToggleItem.length = hiddenToggleLength
        guard let button = hiddenToggleItem.button else { return }
        button.title = "│"
        button.font = .systemFont(ofSize: 13, weight: .regular)
        button.alignment = .center
        button.toolTip = L10n.text("menuBarHiddenSeparatorHint", model.language)
        button.target = self
        button.action = #selector(separatorPressed(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureSeparator(_ item: NSStatusItem, title: String, tooltipKey: String) {
'''
))

replacements.append((
'''    @objc private func separatorPressed(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .leftMouseUp, sender === hiddenSeparatorItem.button {
            toggleHiddenArea()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu(from: sender)
        }
    }
''',
'''    @objc private func separatorPressed(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .leftMouseUp, sender === hiddenToggleItem.button {
            toggleHiddenArea()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu(from: sender)
        }
    }
'''
))

replacements.append((
'''        let wide = collapsedLength()
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
''',
'''        let wide = collapsedLength()
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
'''
))

replacements.append((
'''    private func setSeparatorLengths(hidden: CGFloat, always: CGFloat, animated: Bool) {
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
''',
'''    private func setSpacerLengths(hidden: CGFloat, always: CGFloat, animated: Bool) {
        animationTimer?.invalidate()
        animationTimer = nil

        let hiddenStart = hiddenSpacerItem.length
        let alwaysStart = alwaysHiddenSeparatorItem.length
        guard animated,
              abs(hiddenStart - hidden) > 0.5 || abs(alwaysStart - always) > 0.5 else {
            hiddenSpacerItem.length = hidden
            alwaysHiddenSeparatorItem.length = always
            hiddenToggleItem.length = hiddenToggleLength
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
'''
))

replacements.append((
'''        // A chevron communicates “reveal” while collapsed; the divider communicates “collapse”
        // once the hidden area is visible. Both states remain the same dedicated left-click target.
        hiddenSeparatorItem.button?.title = state == .collapsed ? "‹" : "│"
        hiddenSeparatorItem.button?.toolTip = L10n.text("menuBarHiddenSeparatorHint", model.language)
        alwaysHiddenSeparatorItem.button?.toolTip = L10n.text("menuBarAlwaysSeparatorHint", model.language)
''',
'''        // The toggle has a fixed status-item width and never participates in hiding. The separate
        // spacer may grow thousands of points to its left without pushing this control away.
        hiddenToggleItem.length = hiddenToggleLength
        hiddenToggleItem.button?.title = state == .collapsed ? "‹" : "│"
        hiddenToggleItem.button?.toolTip = L10n.text("menuBarHiddenSeparatorHint", model.language)
        alwaysHiddenSeparatorItem.button?.toolTip = L10n.text("menuBarAlwaysSeparatorHint", model.language)
'''
))

replacements.append((
'''    private func positionValidation() -> PositionValidation {
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
''',
'''    private func positionValidation() -> PositionValidation {
        let rtl = NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft
        guard let controlX = orderAnchorX(controlItem, rtl: rtl),
              let toggleX = orderAnchorX(hiddenToggleItem, rtl: rtl),
              let spacerX = orderAnchorX(hiddenSpacerItem, rtl: rtl) else {
            return .unavailable
        }

        // Expected visual order on LTR menu bars:
        // Always Hidden ¦ → hidden spacer → persistent ‹/│ toggle → Ops Notch.
        let toggleValid = rtl ? controlX <= toggleX : controlX >= toggleX
        let spacerValid = rtl ? toggleX <= spacerX : toggleX >= spacerX
        guard toggleValid, spacerValid else { return .invalid }

        guard model.settings.menuBarAlwaysHiddenEnabled else { return .valid }
        guard let alwaysX = orderAnchorX(alwaysHiddenSeparatorItem, rtl: rtl) else { return .unavailable }
        return (rtl ? spacerX <= alwaysX : spacerX >= alwaysX) ? .valid : .invalid
    }
'''
))

replacements.append((
'''        alert.informativeText = model.language == .zhCN
            ? "按住 ⌘ 拖动菜单栏项目，确保顺序为：持续隐藏 ¦ → 普通隐藏 │ → Ops Notch。调整后再次选择“收起”。"
            : "Hold ⌘ and drag menu bar items so the order is: Always Hidden ¦ → Hidden │ → Ops Notch, then choose Collapse again."
''',
'''        alert.informativeText = model.language == .zhCN
            ? "按住 ⌘ 拖动可见菜单栏项目，确保顺序为：持续隐藏 ¦ → ‹/│ → Ops Notch。隐藏 Spacer 会自动位于 ‹/│ 左侧。调整后再次选择“收起”。"
            : "Hold ⌘ and arrange the visible controls as: Always Hidden ¦ → ‹/│ → Ops Notch. The hidden spacer stays immediately left of ‹/│. Then choose Collapse again."
'''
))

replacements.append((
'''    private func itemX(_ item: NSStatusItem) -> CGFloat? {
        item.button?.window?.frame.minX
    }
''',
'''    private func orderAnchorX(_ item: NSStatusItem, rtl: Bool) -> CGFloat? {
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
'''
))

replacements.append((
'''            let hiddenX = self.itemX(self.hiddenSeparatorItem)
            let alwaysX = self.model.settings.menuBarAlwaysHiddenEnabled ? self.itemX(self.alwaysHiddenSeparatorItem) : nil
            guard let hiddenX else {
''',
'''            let rtl = NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft
            let hiddenX = self.hiddenBoundaryX(self.hiddenSpacerItem, rtl: rtl)
            let alwaysX = self.model.settings.menuBarAlwaysHiddenEnabled
                ? self.hiddenBoundaryX(self.alwaysHiddenSeparatorItem, rtl: rtl)
                : nil
            guard let hiddenX else {
'''
))

replacements.append((
'''                rtl: NSApplication.shared.userInterfaceLayoutDirection == .rightToLeft,
''',
'''                rtl: rtl,
'''
))

for old, new in replacements:
    if old not in text:
        raise SystemExit(f'anchor not found:\n{old[:240]}')
    text = text.replace(old, new, 1)

# Hard safety checks: the variable-width interactive separator must be fully removed.
if 'hiddenSeparatorItem' in text:
    raise SystemExit('hiddenSeparatorItem reference remains after migration')
if 'setSeparatorLengths' in text:
    raise SystemExit('old setSeparatorLengths reference remains after migration')

path.write_text(text)

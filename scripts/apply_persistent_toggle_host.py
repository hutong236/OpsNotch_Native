from pathlib import Path

path = Path('Sources/OpsNotchApp/MenuBarManager.swift')
text = path.read_text()

replacements = []

replacements.append(('''    private let model: AppModel
    private let controlItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    // AppKit inserts later status items to the left by default. Create toggle before spacer so the
    // new invisible spacer naturally lands immediately to the left of the persistent toggle.
    private let hiddenToggleItem = NSStatusBar.system.statusItem(withLength: 16)
    private let hiddenSpacerItem = NSStatusBar.system.statusItem(withLength: 1)
    private let alwaysHiddenSeparatorItem = NSStatusBar.system.statusItem(withLength: 12)
    private let hotkey: HotkeyService = CarbonHotkeyService(id: 2)

    private var statusMenuProvider: (() -> NSMenu)?
''', '''    private let model: AppModel
    private let controlItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    // One host item owns both the variable-width hiding spacer and the persistent toggle button.
    // The child toggle is pinned to the edge nearest Ops Notch, so changing host width can never
    // move the user's reveal/collapse control into the hidden side of the menu bar.
    private let hiddenHostItem = NSStatusBar.system.statusItem(withLength: 17)
    private let alwaysHiddenSeparatorItem = NSStatusBar.system.statusItem(withLength: 12)
    private let hotkey: HotkeyService = CarbonHotkeyService(id: 2)

    private var hiddenToggleButton: NSButton?
    private var statusMenuProvider: (() -> NSMenu)?
'''))

replacements.append(('''    private let separatorLength: CGFloat = 12
    private let hiddenToggleLength: CGFloat = 16
    private let hiddenSpacerRestingLength: CGFloat = 1
    private let animationDuration: TimeInterval = 0.16
''', '''    private let separatorLength: CGFloat = 12
    private let hiddenToggleLength: CGFloat = 16
    private let hiddenHostRestingLength: CGFloat = 17
    private let animationDuration: TimeInterval = 0.16
'''))

replacements.append(('''        hiddenSpacerItem.isVisible = enabled
        hiddenToggleItem.isVisible = enabled
        alwaysHiddenSeparatorItem.isVisible = enabled && settings.menuBarAlwaysHiddenEnabled
        controlItem.isVisible = true
        hiddenToggleItem.length = hiddenToggleLength
        hiddenSpacerItem.length = max(hiddenSpacerItem.length, hiddenSpacerRestingLength)
''', '''        hiddenHostItem.isVisible = enabled
        alwaysHiddenSeparatorItem.isVisible = enabled && settings.menuBarAlwaysHiddenEnabled
        controlItem.isVisible = true
        hiddenHostItem.length = max(hiddenHostItem.length, hiddenHostRestingLength)
'''))

replacements.append(('''        guard let hiddenX = hiddenBoundaryX(hiddenSpacerItem, rtl: safeArea.rtl) else {
''', '''        guard let hiddenX = hiddenBoundaryX(hiddenHostItem, rtl: safeArea.rtl) else {
'''))

replacements.append(('''        controlItem.autosaveName = "lab.hutong.opsnotch.menubar.control"
        // Reuse the old hidden-separator autosave key for the visible toggle so upgrades preserve
        // the user's established boundary position. The new invisible spacer gets its own key.
        hiddenToggleItem.autosaveName = "lab.hutong.opsnotch.menubar.hidden-separator"
        hiddenSpacerItem.autosaveName = "lab.hutong.opsnotch.menubar.hidden-spacer"
        alwaysHiddenSeparatorItem.autosaveName = "lab.hutong.opsnotch.menubar.always-hidden-separator"

        controlItem.isVisible = true
        hiddenToggleItem.isVisible = true
        hiddenSpacerItem.isVisible = true
        alwaysHiddenSeparatorItem.isVisible = true
''', '''        controlItem.autosaveName = "lab.hutong.opsnotch.menubar.control"
        // Keep the legacy hidden-separator autosave key on the combined host so upgrades retain
        // the user's established boundary next to Ops Notch.
        hiddenHostItem.autosaveName = "lab.hutong.opsnotch.menubar.hidden-separator"
        alwaysHiddenSeparatorItem.autosaveName = "lab.hutong.opsnotch.menubar.always-hidden-separator"

        controlItem.isVisible = true
        hiddenHostItem.isVisible = true
        alwaysHiddenSeparatorItem.isVisible = true
'''))

replacements.append(('''        configureHiddenSpacer()
        configureHiddenToggle()
        configureSeparator(alwaysHiddenSeparatorItem, title: "¦", tooltipKey: "menuBarAlwaysSeparatorHint")
''', '''        configureHiddenHost()
        configureSeparator(alwaysHiddenSeparatorItem, title: "¦", tooltipKey: "menuBarAlwaysSeparatorHint")
'''))

old_helpers = '''    private func configureHiddenSpacer() {
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
'''
new_helpers = '''    private func configureHiddenHost() {
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
'''
replacements.append((old_helpers, new_helpers))

replacements.append(('''    @objc private func separatorPressed(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .leftMouseUp, sender === hiddenToggleItem.button {
            toggleHiddenArea()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu(from: sender)
        }
    }
''', '''    @objc private func hiddenTogglePressed(_ sender: NSButton) {
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
'''))

replacements.append(('''        switch newState {
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
''', '''        switch newState {
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
'''))

old_lengths = '''    private func setSpacerLengths(hidden: CGFloat, always: CGFloat, animated: Bool) {
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
new_lengths = '''    private func setHostLengths(hidden: CGFloat, always: CGFloat, animated: Bool) {
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
'''
replacements.append((old_lengths, new_lengths))

replacements.append(('''        // The toggle has a fixed status-item width and never participates in hiding. The separate
        // spacer may grow thousands of points to its left without pushing this control away.
        hiddenToggleItem.length = hiddenToggleLength
        hiddenToggleItem.button?.title = state == .collapsed ? "‹" : "│"
        hiddenToggleItem.button?.toolTip = L10n.text("menuBarHiddenSeparatorHint", model.language)
''', '''        // The toggle is a fixed child view pinned to the host's visible edge. The host itself can
        // grow thousands of points toward the hidden side without moving this button away.
        hiddenToggleButton?.title = state == .collapsed ? "‹" : "│"
        hiddenToggleButton?.toolTip = L10n.text("menuBarHiddenSeparatorHint", model.language)
'''))

old_validation = '''    private func positionValidation() -> PositionValidation {
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
new_validation = '''    private func positionValidation() -> PositionValidation {
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
'''
replacements.append((old_validation, new_validation))

replacements.append(('''            ? "按住 ⌘ 拖动可见菜单栏项目，确保顺序为：持续隐藏 ¦ → ‹/│ → Ops Notch。隐藏 Spacer 会自动位于 ‹/│ 左侧。调整后再次选择“收起”。"
            : "Hold ⌘ and arrange the visible controls as: Always Hidden ¦ → ‹/│ → Ops Notch. The hidden spacer stays immediately left of ‹/│. Then choose Collapse again."
''', '''            ? "按住 ⌘ 拖动可见菜单栏项目，确保顺序为：持续隐藏 ¦ → ‹/│ → Ops Notch。隐藏占位已集成在 ‹/│ 控件内部。调整后再次选择“收起”。"
            : "Hold ⌘ and arrange the visible controls as: Always Hidden ¦ → ‹/│ → Ops Notch. The hiding spacer is integrated into the ‹/│ host. Then choose Collapse again."
'''))

replacements.append(('''            let hiddenX = self.hiddenBoundaryX(self.hiddenSpacerItem, rtl: rtl)
''', '''            let hiddenX = self.hiddenBoundaryX(self.hiddenHostItem, rtl: rtl)
'''))

for old, new in replacements:
    assert old in text, f'anchor not found:\n{old[:180]}'
    text = text.replace(old, new, 1)

text = text.replace('''/// 仅通过自己的 NSStatusItem spacer 改变占位宽度，不读取或修改第三方状态项。
/// 左侧可形成“持续隐藏 / 普通隐藏 / 始终显示”三段；隐藏 spacer 与常驻 toggle 分离，
/// 用户始终可以通过 ‹ / │ 控件展开或收起真实系统菜单栏隐藏区域。
''', '''/// 仅通过自己的 NSStatusItem host 改变占位宽度，不读取或修改第三方状态项。
/// 左侧可形成“持续隐藏 / 普通隐藏 / 始终显示”三段；隐藏占位与 ‹ / │ 常驻按钮位于同一 Host，
/// Host 变宽时按钮固定在靠 Ops Notch 一侧，因此展开入口不会被一起推走。
''', 1)

assert 'hiddenSpacerItem' not in text
assert 'hiddenToggleItem' not in text
assert 'hiddenSpacerRestingLength' not in text

path.write_text(text)

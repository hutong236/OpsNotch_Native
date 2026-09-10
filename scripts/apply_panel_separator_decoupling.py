from pathlib import Path

path = Path('Sources/OpsNotchApp/MenuBarManager.swift')
text = path.read_text()

old = '''        configureSeparator(hiddenSeparatorItem, title: "│", tooltipKey: "menuBarHiddenSeparatorHint")
        configureSeparator(alwaysHiddenSeparatorItem, title: "¦", tooltipKey: "menuBarAlwaysSeparatorHint")
        updateControlAppearance()
'''
new = '''        configureSeparator(hiddenSeparatorItem, title: "│", tooltipKey: "menuBarHiddenSeparatorHint")
        // The separator is the dedicated control for revealing/collapsing the real system menu-bar area.
        // Keep the Ops Notch control itself dedicated to the hidden-items proxy panel.
        hiddenSeparatorItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        configureSeparator(alwaysHiddenSeparatorItem, title: "¦", tooltipKey: "menuBarAlwaysSeparatorHint")
        updateControlAppearance()
'''
assert old in text, 'configureStatusItems anchor not found'
text = text.replace(old, new, 1)

old = '''        if !model.settings.menuBarManagementEnabled {
            showContextMenu(from: sender)
        } else if event.modifierFlags.contains(.option) {
            showAll()
        } else if model.settings.menuBarPanelEnabled {
            showHiddenItemsPanel()
        } else {
            toggleHiddenArea()
        }
    }

    @objc private func separatorPressed(_ sender: NSStatusBarButton) {
        showContextMenu(from: sender)
    }
'''
new = '''        if !model.settings.menuBarManagementEnabled {
            showContextMenu(from: sender)
        } else if model.settings.menuBarPanelEnabled {
            // Left-clicking the Ops Notch icon is now a pure panel action. It must never expand
            // the underlying system menu-bar area as a side effect.
            showHiddenItemsPanel()
        } else {
            showContextMenu(from: sender)
        }
    }

    @objc private func separatorPressed(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .leftMouseUp, sender === hiddenSeparatorItem.button {
            toggleHiddenArea()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu(from: sender)
        }
    }
'''
assert old in text, 'control/separator interaction anchor not found'
text = text.replace(old, new, 1)

old = '''        stagedPanelItems.removeAll(keepingCapacity: true)
        let hadCachedItems = !rawPanelItems.isEmpty
        panelController.beginRefresh(preserveItems: hadCachedItems)
        let previous = state
        applyState(.allExpanded, animated: false, scheduleAutoHide: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
'''
new = '''        stagedPanelItems.removeAll(keepingCapacity: true)
        let hadCachedItems = !rawPanelItems.isEmpty
        panelController.beginRefresh(preserveItems: hadCachedItems)
        let scanLayoutState = state

        // AX can inspect menu-extra elements while their status items are displaced by our spacer.
        // Never expand the real system menu bar just to populate the proxy panel.
        DispatchQueue.main.async { [weak self] in
'''
assert old in text, 'refresh start anchor not found'
text = text.replace(old, new, 1)

old = '''            guard let self, generation == self.panelScanGeneration else { return }
            let hiddenX = self.itemX(self.hiddenSeparatorItem)
'''
new = '''            guard let self,
                  generation == self.panelScanGeneration,
                  scanLayoutState == self.state else { return }
            let hiddenX = self.itemX(self.hiddenSeparatorItem)
'''
assert old in text, 'refresh guard anchor not found'
text = text.replace(old, new, 1)

text = text.replace('''                self.panelController.setUnavailable(L10n.text("menuBarPanelUnavailable", self.model.language))
                self.applyState(previous, animated: false, scheduleAutoHide: true)
                return
''', '''                self.panelController.setUnavailable(L10n.text("menuBarPanelUnavailable", self.model.language))
                return
''', 1)

text = text.replace('''                    self.panelController.setItems(visible.map(\\.presentation), refreshing: false)
                    self.applyState(previous, animated: false, scheduleAutoHide: true)
''', '''                    self.panelController.setItems(visible.map(\\.presentation), refreshing: false)
''', 1)

text = text.replace('''                self.applyState(previous, animated: false, scheduleAutoHide: true)
            }
        }
''', '''            }
        }
''', 1)

old = '''        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Ops Notch")
        image?.isTemplate = true
        button.image = image
        button.toolTip = L10n.text(stateKey, model.language)
        hiddenSeparatorItem.button?.toolTip = L10n.text("menuBarHiddenSeparatorHint", model.language)
'''
new = '''        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Ops Notch")
        image?.isTemplate = true
        button.image = image
        button.toolTip = L10n.text(stateKey, model.language)
        // A chevron communicates “reveal” while collapsed; the divider communicates “collapse”
        // once the hidden area is visible. Both states remain the same dedicated left-click target.
        hiddenSeparatorItem.button?.title = state == .collapsed ? "‹" : "│"
        hiddenSeparatorItem.button?.toolTip = L10n.text("menuBarHiddenSeparatorHint", model.language)
'''
assert old in text, 'appearance anchor not found'
text = text.replace(old, new, 1)

path.write_text(text)

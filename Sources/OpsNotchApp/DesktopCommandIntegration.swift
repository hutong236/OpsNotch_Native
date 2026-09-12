#if os(macOS)
import AppKit
import OpsNotchCore

@MainActor
final class DesktopCommandIntegration {
    weak var shelf: ShelfWindowController?
    var beforeDesktopAction: (() -> Void)?

    private weak var model: AppModel?
    private let spaces = DesktopSpaceController()
    private var preparedMoveSource: DesktopCapturedWindow?
    private var sessionMoveSource: DesktopCapturedWindow?
    private var hasKeyboardSession = false
    private var isPerformingAction = false

    init(model: AppModel) {
        self.model = model
        model.requestDesktopCommand = { [weak self] command in
            self?.execute(command)
        }
    }

    func captureSourceWindow() {
        sessionMoveSource = spaces.captureCurrentWindowForMove()
        hasKeyboardSession = true
    }

    func endKeyboardSession() {
        sessionMoveSource = nil
        hasKeyboardSession = false
        // preparedMoveSource belongs to NSMenu's synchronous tracking session;
        // it must survive a Shelf hide until the selected action has copied it.
    }

    private func execute(_ command: DesktopCommand) {
        guard !isPerformingAction else {
            if let model { model.showToast(L10n.text("desktopActionBusy", model.language)) }
            return
        }
        switch command {
        case .list:
            showDesktopMenu()
        case .switchTo(let index):
            switchToDesktop(index)
        }
    }

    private func showDesktopMenu() {
        guard let model else { return }

        // Freeze the original app's focused window before NSMenu starts its
        // tracking loop. Resolving it after the menu closes can race Shelf
        // focus restoration and select the wrong application or no window.
        preparedMoveSource = hasKeyboardSession ? sessionMoveSource : spaces.captureCurrentWindowForMove()
        defer { preparedMoveSource = nil }

        switch spaces.desktops() {
        case .failure(let error):
            model.showToast(message(for: error))
        case .success(let desktops):
            guard !desktops.isEmpty else {
                model.showToast(L10n.text("desktopNoSpaces", model.language))
                return
            }

            model.query = ""

            let menu = NSMenu(title: L10n.text("desktopList", model.language))
            menu.autoenablesItems = false
            if let source = preparedMoveSource {
                let sourceItem = NSMenuItem(title: String(format: L10n.text("desktopMoveSource", model.language),
                    source.application.localizedName ?? "App"), action: nil, keyEquivalent: "")
                sourceItem.isEnabled = false
                menu.addItem(sourceItem)
                menu.addItem(.separator())
            }
            let moveMenu = NSMenu()
            let followMenu = NSMenu()
            for desktop in desktops {
                var title = "d \(desktop.index)  \(L10n.text("desktop", model.language)) \(desktop.index)"
                let displayLabel = "\(L10n.text("desktopDisplay", model.language)) \(desktop.displayOrder + 1)：\(desktop.displayName)"
                title += " · \(displayLabel)"
                if desktop.isFullscreen {
                    title += " · \(L10n.text("desktopFullscreen", model.language))"
                }
                if desktop.isCurrent {
                    title += "  ✓ \(L10n.text("desktopCurrent", model.language))"
                }

                let item = NSMenuItem(
                    title: title,
                    action: #selector(selectDesktop(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = desktop
                menu.addItem(item)

                guard !desktop.isFullscreen else { continue }

                // Explicit mouse/keyboard actions also work without modifiers.
                for (submenu, selector) in [(moveMenu, #selector(moveWindowToDesktop(_:))),
                                             (followMenu, #selector(moveWindowAndFollowDesktop(_:)))] {
                    let explicitItem = NSMenuItem(title: title, action: selector, keyEquivalent: "")
                    explicitItem.target = self
                    explicitItem.representedObject = desktop
                    submenu.addItem(explicitItem)
                }
            }

            menu.addItem(.separator())
            for (key, submenu) in [("desktopMoveMenu", moveMenu), ("desktopFollowMenu", followMenu)] {
                let parent = NSMenuItem(title: L10n.text(key, model.language), action: nil, keyEquivalent: "")
                parent.submenu = submenu
                parent.isEnabled = !submenu.items.isEmpty
                menu.addItem(parent)
            }
            menu.addItem(.separator())
            let hint = NSMenuItem(
                title: L10n.text("desktopMoveHint", model.language),
                action: nil,
                keyEquivalent: ""
            )
            hint.isEnabled = false
            menu.addItem(hint)

            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }

    @objc
    private func selectDesktop(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? DesktopSpaceDescriptor else { return }
        let flags = desktopMenuModifierFlags()
        let action = DesktopTargetSelectionResolver.resolve(
            optionPressed: flags.contains(.option),
            shiftPressed: flags.contains(.shift)
        )
        desktopWindowLog.info("desktop target selected index=\(target.index, privacy: .public) space=\(target.spaceID, privacy: .public) option=\(flags.contains(.option), privacy: .public) shift=\(flags.contains(.shift), privacy: .public) action=\(String(describing: action), privacy: .public)")
        switch action {
        case .switchDesktop:
            switchToDesktop(target.index, expectedTarget: target)
        case .moveWindow:
            moveCurrentWindow(to: target, follow: false)
        case .moveWindowAndFollow:
            moveCurrentWindow(to: target, follow: true)
        }
    }

    /// Read both the event that dispatched the NSMenu action and the live
    /// modifier state. AppKit popup-menu tracking can consume flagsChanged
    /// events before the target/action callback runs.
    private func desktopMenuModifierFlags() -> NSEvent.ModifierFlags {
        var flags = NSEvent.modifierFlags
        if let event = NSApp.currentEvent {
            flags.formUnion(event.modifierFlags)
        }
        return flags.intersection(.deviceIndependentFlagsMask)
    }

    @objc
    private func moveWindowToDesktop(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? DesktopSpaceDescriptor else { return }
        moveCurrentWindow(to: target, follow: false)
    }

    @objc
    private func moveWindowAndFollowDesktop(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? DesktopSpaceDescriptor else { return }
        moveCurrentWindow(to: target, follow: true)
    }

    private func switchToDesktop(_ index: Int, expectedTarget: DesktopSpaceDescriptor? = nil) {
        guard let model, !isPerformingAction else { return }
        isPerformingAction = true

        model.query = ""
        beforeDesktopAction?()
        shelf?.hide()

        Task { @MainActor [weak self] in
            guard let self, let model = self.model else { return }
            defer { self.isPerformingAction = false }
            let result = await self.spaces.switchToDesktop(index, expectedTarget: expectedTarget)

            switch result {
            case .success:
                break
            case .failure(let error):
                model.showToast(self.message(for: error))
                if self.shelf?.isPanelVisible != true {
                    self.shelf?.toggleSummon()
                }
            }
        }
    }

    private func moveCurrentWindow(to target: DesktopSpaceDescriptor, follow: Bool) {
        guard let model, !isPerformingAction else { return }
        isPerformingAction = true

        // Capture this value before hiding the Shelf; the hide/focus callbacks
        // are asynchronous and must not change which window is being moved.
        let sourceWindow = preparedMoveSource

        model.query = ""
        beforeDesktopAction?()
        shelf?.hide()

        Task { @MainActor [weak self] in
            guard let self, let model = self.model else { return }
            defer { self.isPerformingAction = false }
            let result = await self.spaces.moveCurrentWindow(
                toDesktop: target,
                follow: follow,
                capturedWindow: sourceWindow
            )

            switch result {
            case .success:
                break
            case .failure(let error):
                model.showToast(self.message(for: error))
                if self.shelf?.isPanelVisible != true {
                    self.shelf?.toggleSummon()
                }
            }
        }
    }

    private func message(for error: DesktopSpaceSwitchError) -> String {
        guard let model else { return "" }
        switch error {
        case .accessibilityRequired:
            return L10n.text("desktopAccessibilityRequired", model.language)
        case .topologyUnavailable:
            return L10n.text("desktopTopologyUnavailable", model.language)
        case .desktopNotFound(let index):
            return String(
                format: L10n.text("desktopNotFound", model.language),
                index
            )
        case .switchFailed(let index):
            return String(
                format: L10n.text("desktopSwitchFailed", model.language),
                index
            )
        }
    }

    private func message(for error: DesktopWindowMoveError) -> String {
        guard let model else { return "" }
        switch error {
        case .accessibilityRequired:
            return L10n.text("desktopAccessibilityRequired", model.language)
        case .topologyUnavailable:
            return L10n.text("desktopTopologyUnavailable", model.language)
        case .desktopNotFound(let index):
            return String(
                format: L10n.text("desktopNotFound", model.language),
                index
            )
        case .fullscreenUnsupported:
            return L10n.text("desktopFullscreenMoveUnsupported", model.language)
        case .activeWindowUnavailable:
            return L10n.text("desktopWindowUnavailable", model.language)
        case .windowIdentifierUnavailable:
            return L10n.text("desktopWindowIDUnavailable", model.language)
        case .moveAPIUnavailable:
            return L10n.text("desktopMoveUnavailable", model.language)
        case .singleSpaceRequired:
            return L10n.text("desktopSingleSpaceRequired", model.language)
        case .separateSpacesRequired:
            return L10n.text("desktopSeparateSpacesRequired", model.language)
        case .displayLayoutChanged:
            return L10n.text("desktopDisplayLayoutChanged", model.language)
        case .targetDisplayFullscreen:
            return L10n.text("desktopTargetDisplayFullscreen", model.language)
        case .displayPlacementFailed:
            return L10n.text("desktopDisplayPlacementFailed", model.language)
        case .focusFailed:
            return L10n.text("desktopMoveFocusFailed", model.language)
        case .moveFailed(let index):
            return String(
                format: L10n.text("desktopMoveFailed", model.language),
                index
            )
        case .followSwitchFailed(let index):
            return String(
                format: L10n.text("desktopMoveFollowFailed", model.language),
                index
            )
        }
    }
}
#endif

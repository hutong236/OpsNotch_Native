#if os(macOS)
import AppKit
import OpsNotchCore

@MainActor
final class DesktopCommandIntegration {
    weak var shelf: ShelfWindowController?

    private weak var model: AppModel?
    private let spaces = DesktopSpaceController()

    init(model: AppModel) {
        self.model = model
        model.requestDesktopCommand = { [weak self] command in
            self?.execute(command)
        }
    }

    private func execute(_ command: DesktopCommand) {
        switch command {
        case .list:
            showDesktopMenu()
        case .switchTo(let index):
            switchToDesktop(index)
        }
    }

    private func showDesktopMenu() {
        guard let model else { return }

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
            for desktop in desktops {
                var title = "d \(desktop.index)  \(L10n.text("desktop", model.language)) \(desktop.index)"
                title += " · \(desktop.displayName)"
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
                item.representedObject = desktop.index
                menu.addItem(item)

                guard !desktop.isFullscreen else { continue }

                let moveItem = NSMenuItem(
                    title: String(
                        format: L10n.text("desktopMoveWindow", model.language),
                        desktop.index
                    ),
                    action: #selector(moveWindowToDesktop(_:)),
                    keyEquivalent: ""
                )
                moveItem.target = self
                moveItem.representedObject = desktop.index
                moveItem.isAlternate = true
                moveItem.keyEquivalentModifierMask = [.option]
                menu.addItem(moveItem)

                let moveAndFollowItem = NSMenuItem(
                    title: String(
                        format: L10n.text("desktopMoveAndFollow", model.language),
                        desktop.index
                    ),
                    action: #selector(moveWindowAndFollowDesktop(_:)),
                    keyEquivalent: ""
                )
                moveAndFollowItem.target = self
                moveAndFollowItem.representedObject = desktop.index
                moveAndFollowItem.isAlternate = true
                moveAndFollowItem.keyEquivalentModifierMask = [.option, .shift]
                menu.addItem(moveAndFollowItem)
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
        guard let index = sender.representedObject as? Int else { return }
        switchToDesktop(index)
    }

    @objc
    private func moveWindowToDesktop(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        moveCurrentWindow(to: index, follow: false)
    }

    @objc
    private func moveWindowAndFollowDesktop(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        moveCurrentWindow(to: index, follow: true)
    }

    private func switchToDesktop(_ index: Int) {
        guard let model else { return }

        model.query = ""
        shelf?.hide()

        Task { @MainActor [weak self] in
            guard let self, let model = self.model else { return }
            let result = await self.spaces.switchToDesktop(index)

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

    private func moveCurrentWindow(to index: Int, follow: Bool) {
        guard let model else { return }

        model.query = ""
        shelf?.hide()

        Task { @MainActor [weak self] in
            guard let self, let model = self.model else { return }
            let result = await self.spaces.moveCurrentWindow(toDesktop: index, follow: follow)

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

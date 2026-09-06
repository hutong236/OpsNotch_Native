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
            }

            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }

    @objc
    private func selectDesktop(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        switchToDesktop(index)
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
}
#endif

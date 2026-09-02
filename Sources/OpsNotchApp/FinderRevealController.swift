#if os(macOS)
import AppKit
import Combine
import OpsNotchCore

/// Finder 定位功能的业务协调器：管理第二个全局快捷键，并调用 SpotlightRevealService。
@MainActor
final class FinderRevealController: ObservableObject {
    @Published private(set) var hotkeyConflict = false

    private let model: AppModel
    private let hotkey: HotkeyService
    private let spotlight = SpotlightRevealService()

    init(model: AppModel) {
        self.model = model
        let service = CarbonHotkeyService(id: 2)
        hotkey = service
        service.onFire = { [weak self] in self?.revealConfiguredApplication() }
        _ = service.apply(model.settings.finderRevealHotkey)
    }

    func setHotkey(_ shortcut: HotkeyShortcut?) {
        if hotkey.apply(shortcut) != nil {
            hotkeyConflict = true
            return
        }
        hotkeyConflict = false
        model.updateSettings { $0.finderRevealHotkey = shortcut }
    }

    func clearConflict() {
        hotkeyConflict = false
    }

    /// 外部设置变化后使注册状态与持久化配置重新收敛。
    func syncFromSettings() {
        _ = hotkey.apply(model.settings.finderRevealHotkey)
    }

    func revealConfiguredApplication() {
        let name = model.settings.finderRevealAppName
        spotlight.revealApplication(named: name) { [weak self] result in
            guard let self else { return }
            switch result {
            case .revealed:
                break
            case .notFound(let appName):
                NSSound.beep()
                self.model.showToast(L10n.text("finderRevealNotFound", self.model.language) + " \(appName)")
            }
        }
    }
}
#endif

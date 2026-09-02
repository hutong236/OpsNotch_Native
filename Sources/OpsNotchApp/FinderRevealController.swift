#if os(macOS)
import AppKit
import Combine
import OpsNotchCore

/// Finder 快速路径功能协调器：管理第二个全局快捷键，并呼出键盘优先的路径选择面板。
@MainActor
final class FinderRevealController: ObservableObject {
    @Published private(set) var hotkeyConflict = false

    private let model: AppModel
    private let hotkey: HotkeyService
    private let launcher: FinderQuickLauncherWindowController

    init(model: AppModel) {
        self.model = model
        launcher = FinderQuickLauncherWindowController(model: model)
        let service = CarbonHotkeyService(id: 2)
        hotkey = service
        service.onFire = { [weak self] in self?.launcher.toggle() }
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

    func clearConflict() { hotkeyConflict = false }

    /// 外部设置变化后使注册状态与持久化配置重新收敛。
    func syncFromSettings() {
        _ = hotkey.apply(model.settings.finderRevealHotkey)
    }

    func showLauncher() {
        launcher.show()
    }
}
#endif

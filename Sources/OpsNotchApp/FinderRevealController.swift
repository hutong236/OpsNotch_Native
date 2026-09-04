#if os(macOS)
import AppKit
import Combine
import OpsNotchCore

/// Finder 快捷路径兼容入口：保留历史第二快捷键配置，但与主快捷键共享同一个 Quick Shelf。
@MainActor
final class FinderRevealController: ObservableObject {
    @Published private(set) var hotkeyConflict = false

    private let model: AppModel
    private let hotkey: HotkeyService
    private let summonUnifiedShelf: () -> Void

    init(model: AppModel, summonUnifiedShelf: @escaping () -> Void) {
        self.model = model
        self.summonUnifiedShelf = summonUnifiedShelf
        let service = CarbonHotkeyService(id: 2)
        hotkey = service
        service.onFire = { [weak self] in self?.showLauncher() }
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

    /// 方法名保留兼容现有设置页/状态栏调用；实际打开统一 Quick Shelf。
    /// Finder 兼容热键代表明确的“我要目录”意图，因此清除临时搜索/类型筛选并定位默认目录。
    func showLauncher() {
        model.query = ""
        model.setKindFilter(to: .all)
        summonUnifiedShelf()
        model.highlightFinderDefault()
    }
}
#endif

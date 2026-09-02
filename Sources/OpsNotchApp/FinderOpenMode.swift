#if os(macOS)
import Foundation

/// Finder 快速路径的打开策略。
/// 系统默认模式直接交给 NSWorkspace；只有用户主动选择优先 Tab 时才执行 Finder 自动化。
enum FinderOpenMode: String, CaseIterable {
    /// 先复用同路径窗口，否则尝试在现有 Finder 中创建新标签页；失败或超时立即回退。
    case preferTab = "prefer_tab"
    /// 最快且安全的默认值：不做 AppleScript 预检，立即按系统偏好打开。
    case systemDefault = "system_default"
}

enum FinderOpenModePreference {
    static let key = "finder_quick_path_open_mode"

    static var current: FinderOpenMode {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let mode = FinderOpenMode(rawValue: raw) else {
            return .systemDefault
        }
        return mode
    }

    static func set(_ mode: FinderOpenMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: key)
    }
}
#endif

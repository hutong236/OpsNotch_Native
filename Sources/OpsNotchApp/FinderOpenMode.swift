#if os(macOS)
import Foundation

/// Finder 快速路径在目标尚未打开时的打开策略。
/// 同一路径已存在时，无论哪种策略都优先复用现有 Finder 窗口/当前可见目标。
enum FinderOpenMode: String, CaseIterable {
    /// 如果 Finder 已有窗口，尝试在其中创建新标签页；失败或超时立即回退到系统默认打开方式。
    case preferTab = "prefer_tab"
    /// 安全默认：交给 Finder / NSWorkspace 按系统偏好打开。
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

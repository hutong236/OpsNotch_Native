#if os(macOS)
import Foundation

/// 应用版本号读取：唯一权威来源是打包产物 Info.plist 的 CFBundleShortVersionString。
/// 不在 Bundle 中运行时（swift run / 单元测试）回退到 0.0.0-dev。
@MainActor
enum AppVersionService {
    static let fallback = "0.0.0-dev"

    static var current: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !version.isEmpty else {
            return fallback
        }
        return version
    }
}
#endif

#if os(macOS)
import AppKit
import AppIntents

/// 聚焦/快捷指令入口:执行即呼出/收起 Shelf 面板,语义与热键、系统打开事件完全一致
/// (复用 AppDelegate 的统一 summon 接线)。SwiftPM 构建链路不自动运行
/// `appintentsmetadataprocessor`,短语元数据由 `scripts/build_app.sh` 手动提取注入。
struct SummonShelfIntent: AppIntent {
    // AppIntents 标题为编译期 LocalizedStringResource,不走 L10n 运行时字典(项目无 .strings 表)。
    static let title: LocalizedStringResource = "打开 Ops Notch 清单"
    static let description = IntentDescription("唤出或收起 Ops Notch 的 Shelf 面板,搜索框直接可输入。")

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .summonShelfRequested, object: nil)
        return .result()
    }
}

struct OpsNotchAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SummonShelfIntent(),
            phrases: [
                "打开\(.applicationName)清单",
                "Open \(.applicationName) Shelf",
                "\(.applicationName) shelf",
            ],
            shortTitle: "打开清单",
            systemImageName: "square.stack.3d.up"
        )
    }
}

extension Notification.Name {
    static let summonShelfRequested = Notification.Name("lab.hutong.opsnotch.summonShelfRequested")
}
#endif

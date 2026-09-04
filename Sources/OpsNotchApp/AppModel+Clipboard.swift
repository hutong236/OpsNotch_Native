#if os(macOS)
import OpsNotchCore

@MainActor
extension AppModel {
    /// 系统剪贴板自动收集入口。与手动新建文本分离，避免去重规则影响用户主动创建重复内容。
    func captureClipboardText(_ text: String) {
        do {
            _ = try store.captureText(text)
            reload()
            showToast(L10n.text("clipboardCaught", language))
        } catch {
            showToast(error.localizedDescription)
        }
    }
}
#endif

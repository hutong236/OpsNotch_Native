#if os(macOS)
import Foundation
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

    /// Finder 等应用复制文件时，保留文件 URL 语义入柜，避免被 string flavor 降级成文件名/路径文本。
    /// 文件/文件夹沿用当前 Reference / Copy-in 设置；`.app` 仍按应用条目保存。
    func captureClipboardFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        for url in urls {
            do {
                if url.pathExtension.lowercased() == "app" {
                    apply(try store.addApplication(url))
                } else {
                    apply(try store.addPath(url, mode: settings.addMode))
                }
            } catch {
                showToast(error.localizedDescription)
                return
            }
        }
        showToast(L10n.text("clipboardCaught", language))
    }
}
#endif

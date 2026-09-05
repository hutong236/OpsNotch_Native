#if os(macOS)
import Foundation
import OpsNotchCore

@MainActor
extension AppModel {
    /// 系统剪贴板自动收集入口。单趟捕获:store.captureText 在一次 mutate 内完成去重判定与写入,
    /// 结果直接 apply 回内存,不再触发全量 reload(避免二次读写盘)。
    func captureClipboardText(_ text: String) {
        do {
            apply(try store.captureText(text))
            showToast(L10n.text("clipboardCaught", language))
        } catch {
            showToast(error.localizedDescription)
        }
    }

    /// Sensor 拖入文本的捕获入口:与剪贴板捕获语义一致,内容相同则上浮已有条目而非新增。
    /// 拖放流程自身的 ✓ 反馈由 ShelfWindowController 负责,这里不再弹 toast。
    func captureDroppedText(_ text: String) {
        do { apply(try store.captureText(text)) }
        catch { showToast(error.localizedDescription) }
    }

    /// Sensor 拖入 http/https URL 的捕获入口:与 captureText 对称,相同 URL 上浮而非新增。
    func captureDroppedURL(_ text: String) {
        do { apply(try store.captureURL(text)) }
        catch { showToast(error.localizedDescription) }
    }

    /// Finder 等应用复制文件时，保留文件 URL 语义入柜，避免被 string flavor 降级成文件名/路径文本。
    /// 文件/文件夹沿用当前 Reference / Copy-in 设置；`.app` 仍按应用条目保存。
    func captureClipboardFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        let applications = urls.filter { $0.pathExtension.lowercased() == "app" }
        let paths = urls.filter { $0.pathExtension.lowercased() != "app" }

        if !paths.isEmpty {
            addPaths(paths)
        }
        for application in applications {
            addApplication(application)
        }

        showToast(L10n.text("clipboardCaught", language))
    }
}
#endif

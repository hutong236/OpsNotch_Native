#if os(macOS)
import AppKit
import OpsNotchCore

@MainActor
final class ClipboardManager {
    private let model: AppModel
    private var handledChangeCount: Int

    init(model: AppModel) {
        self.model = model
        self.handledChangeCount = NSPasteboard.general.changeCount
    }

    @discardableResult
    func catchIfChanged() -> Bool {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != handledChangeCount else { return false }
        handledChangeCount = pasteboard.changeCount
        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return false }
        model.addText(text)
        return true
    }

    func copyFromApp(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        handledChangeCount = pasteboard.changeCount
    }

    /// "复制所选"写入:同一事务写文件 URL 与文本两种 flavor(与拖出同为 NSURL/NSString writer),
    /// 应用自身写入后立即同步基线,避免复制内容被剪贴板监控回灌 Recent。
    func copyPayload(_ payload: ShelfCopyPayload) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !payload.filePaths.isEmpty {
            pasteboard.writeObjects(payload.filePaths.map { URL(fileURLWithPath: $0) as NSURL })
        }
        if let text = payload.text, !text.isEmpty {
            pasteboard.setString(text, forType: .string)
        }
        handledChangeCount = pasteboard.changeCount
    }

    func markCurrentAsHandled() {
        handledChangeCount = NSPasteboard.general.changeCount
    }
}
#endif

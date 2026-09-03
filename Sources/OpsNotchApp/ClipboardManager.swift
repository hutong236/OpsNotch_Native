#if os(macOS)
import AppKit
import OpsNotchCore

@MainActor
final class ClipboardManager {
    /// NSPasteboard 没有提供通用剪贴板变更通知，因此使用轻量 changeCount 轮询。
    /// 100ms 足以覆盖人工快速连续复制，同时每次只做整数比较，未变化时不会读取内容或写磁盘。
    private static let pollIntervalNanoseconds: UInt64 = 100_000_000

    private let model: AppModel
    private var handledChangeCount: Int
    private var monitorTask: Task<Void, Never>?

    init(model: AppModel) {
        self.model = model
        self.handledChangeCount = NSPasteboard.general.changeCount
    }

    /// 应用启动后持续监听系统剪贴板，避免两次触碰 Sensor 之间连续复制的中间内容被覆盖丢失。
    /// 重复调用是幂等的，生命周期由 AppDelegate 显式启动/停止。
    func startMonitoring() {
        guard monitorTask == nil else { return }
        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: Self.pollIntervalNanoseconds)
                } catch {
                    break
                }
                guard let self else { break }
                _ = self.catchIfChanged()
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
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

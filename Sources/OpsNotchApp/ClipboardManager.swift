#if os(macOS)
import AppKit
import Foundation
import OpsNotchCore

@MainActor
final class ClipboardManager {
    /// NSPasteboard 没有提供通用剪贴板变更通知，因此使用轻量 changeCount 轮询。
    /// 面板可见时 100ms 足以覆盖人工快速连续复制；不可见时放宽到 400ms 减少常驻主线程唤醒
    /// (Sensor 的 mouseEntered 兜底 catchIfChanged 保证唤起时机不受轮询间隔影响)。
    /// 每次只做整数比较，未变化时不会读取内容或写磁盘。
    private static let activePollIntervalNanoseconds: UInt64 = 100_000_000
    private static let idlePollIntervalNanoseconds: UInt64 = 400_000_000
    /// 某些应用一次 ⌘C 会连续更新多个 pasteboard flavor，changeCount 会变化多次但内容相同。
    /// 短时间内相同内容只消费一次；更长时间后的重复复制交给 store 层处理。
    private static let duplicateSuppressionInterval: TimeInterval = 1.0

    /// 去重只需要知道“刚才是不是同一份内容”，不需要把上一份完整剪贴板再强引用一遍。
    /// 对大段日志/代码或大量文件路径，保存固定大小指纹可避免应用长期额外占用同等体积内存。
    private struct ContentFingerprint: Equatable {
        let digest: Int
        let byteCount: Int
        let itemCount: Int
    }

    private let model: AppModel
    private var handledChangeCount: Int
    private var monitorTask: Task<Void, Never>?
    private var lastCapturedTextFingerprint: ContentFingerprint?
    private var lastCapturedTextAt: TimeInterval = 0
    private var lastCapturedFilesFingerprint: ContentFingerprint?
    private var lastCapturedFilesAt: TimeInterval = 0
    /// Shelf 面板可见性提供者,由 AppDelegate 注入;未注入时按不可见处理。
    var panelVisibleProvider: (() -> Bool)?

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
                let visible = self?.panelVisibleProvider?() ?? false
                do {
                    try await Task.sleep(
                        nanoseconds: visible ? Self.activePollIntervalNanoseconds : Self.idlePollIntervalNanoseconds
                    )
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

        // Finder 复制文件时 pasteboard 往往同时包含 fileURL 与 string flavor。
        // 必须优先读取 fileURL，否则会把文件误收集成“文件名/路径文本”，二次取回时只能复制字符串。
        let fileOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: fileOptions) as? [NSURL], !objects.isEmpty {
            let urls = objects.map { $0 as URL }
            let paths = urls.map(\.path)
            let fingerprint = Self.fingerprint(paths: paths)
            let now = ProcessInfo.processInfo.systemUptime
            if fingerprint == lastCapturedFilesFingerprint, now - lastCapturedFilesAt < Self.duplicateSuppressionInterval {
                return false
            }
            lastCapturedFilesFingerprint = fingerprint
            lastCapturedFilesAt = now
            model.captureClipboardFiles(urls)
            return true
        }

        guard let rawText = pasteboard.string(forType: .string) else { return false }
        let text = normalizedClipboardText(rawText)
        guard !text.isEmpty else { return false }

        let fingerprint = Self.fingerprint(text: text)
        let now = ProcessInfo.processInfo.systemUptime
        if fingerprint == lastCapturedTextFingerprint, now - lastCapturedTextAt < Self.duplicateSuppressionInterval {
            return false
        }
        lastCapturedTextFingerprint = fingerprint
        lastCapturedTextAt = now

        model.captureClipboardText(text)
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

    private func normalizedClipboardText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fingerprint(text: String) -> ContentFingerprint {
        var hasher = Hasher()
        hasher.combine(text)
        return ContentFingerprint(
            digest: hasher.finalize(),
            byteCount: text.utf8.count,
            itemCount: 1
        )
    }

    private static func fingerprint(paths: [String]) -> ContentFingerprint {
        var hasher = Hasher()
        var byteCount = 0
        for path in paths {
            hasher.combine(path)
            byteCount += path.utf8.count
        }
        return ContentFingerprint(
            digest: hasher.finalize(),
            byteCount: byteCount,
            itemCount: paths.count
        )
    }
}
#endif

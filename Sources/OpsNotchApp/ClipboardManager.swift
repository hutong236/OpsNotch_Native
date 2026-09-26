#if os(macOS)
import AppKit
import Foundation
import OpsNotchCore

@MainActor
final class ClipboardManager {
    private static let activePollIntervalNanoseconds: UInt64 = 100_000_000
    private static let idlePollIntervalNanoseconds: UInt64 = 400_000_000
    private static let duplicateSuppressionInterval: TimeInterval = 1.0
    private static let pngPasteboardType = NSPasteboard.PasteboardType("public.png")

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
    private var lastCapturedImageFingerprint: ContentFingerprint?
    private var lastCapturedImageAt: TimeInterval = 0
    var panelVisibleProvider: (() -> Bool)?

    init(model: AppModel) {
        self.model = model
        self.handledChangeCount = NSPasteboard.general.changeCount
    }

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
        let sourceAppName = NSWorkspace.shared.frontmostApplication?.localizedName

        // 和拖入使用同一条真实文件 URL 读取规则。先读 pasteboard item 明确声明的 fileURL/path，
        // 避免泛型 NSURL object reader 从文件内容 flavor 生成 /tmp/... 临时路径。
        let urls = PasteboardFileURLReader.read(from: pasteboard)
        if !urls.isEmpty {
            let paths = urls.map(\.path)
            let fingerprint = Self.fingerprint(paths: paths)
            let now = ProcessInfo.processInfo.systemUptime
            if fingerprint == lastCapturedFilesFingerprint,
               now - lastCapturedFilesAt < Self.duplicateSuppressionInterval {
                return false
            }
            lastCapturedFilesFingerprint = fingerprint
            lastCapturedFilesAt = now
            model.captureClipboardFiles(urls, sourceAppName: sourceAppName)
            return true
        }

        if let imageData = normalizedPNGData(from: pasteboard) {
            let fingerprint = Self.fingerprint(data: imageData)
            let now = ProcessInfo.processInfo.systemUptime
            if fingerprint == lastCapturedImageFingerprint,
               now - lastCapturedImageAt < Self.duplicateSuppressionInterval {
                return false
            }
            lastCapturedImageFingerprint = fingerprint
            lastCapturedImageAt = now
            model.captureClipboardImageData(imageData, sourceAppName: sourceAppName)
            return true
        }

        guard let rawText = pasteboard.string(forType: .string) else { return false }
        let text = normalizedClipboardText(rawText)
        guard !text.isEmpty else { return false }

        let fingerprint = Self.fingerprint(text: text)
        let now = ProcessInfo.processInfo.systemUptime
        if fingerprint == lastCapturedTextFingerprint,
           now - lastCapturedTextAt < Self.duplicateSuppressionInterval {
            return false
        }
        lastCapturedTextFingerprint = fingerprint
        lastCapturedTextAt = now

        model.captureClipboardText(text, sourceAppName: sourceAppName)
        return true
    }

    func copyFromApp(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        handledChangeCount = pasteboard.changeCount
    }

    @discardableResult
    func copyImageFile(_ path: String) -> Bool {
        guard let image = NSImage(contentsOfFile: path),
              let tiff = image.tiffRepresentation else { return false }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(tiff, forType: .tiff)
        if let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            pasteboard.setData(png, forType: Self.pngPasteboardType)
        }
        handledChangeCount = pasteboard.changeCount
        return true
    }

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

    private func normalizedPNGData(from pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: Self.pngPasteboardType), !png.isEmpty {
            return png
        }
        guard let tiff = pasteboard.data(forType: .tiff),
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
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

    private static func fingerprint(data: Data) -> ContentFingerprint {
        var hasher = Hasher()
        hasher.combine(data)
        return ContentFingerprint(
            digest: hasher.finalize(),
            byteCount: data.count,
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

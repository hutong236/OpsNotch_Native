#if os(macOS)
import AppKit
import Foundation
import OpsNotchCore

@MainActor
final class ClipboardManager {
    private static let duplicateSuppressionInterval: TimeInterval = 1.0
    private static let pngPasteboardType = NSPasteboard.PasteboardType("public.png")

    private struct ContentFingerprint: Equatable, Sendable {
        let digest: Int
        let byteCount: Int
        let itemCount: Int
    }

    private enum CaptureWork: Sendable {
        case files([URL], sourceAppName: String?)
        case image(Data, source: ClipboardImageNormalizer.Source, sourceAppName: String?)
        case text(String, sourceAppName: String?)
    }

    private let model: AppModel
    private var handledChangeCount: Int
    private var monitorTask: Task<Void, Never>?
    private var captureProcessingTask: Task<Void, Never>?
    private var pendingCaptures: [CaptureWork] = []
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
                let schedule = ClipboardPollingPolicy.schedule(panelVisible: visible)
                do {
                    try await Task.sleep(
                        for: .milliseconds(schedule.intervalMilliseconds),
                        tolerance: .milliseconds(schedule.toleranceMilliseconds)
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

    /// MainActor work is intentionally limited to reading the system pasteboard and queueing
    /// an immutable payload. Normalization, hashing, file copy and shelf persistence happen
    /// asynchronously so AppKit event handling cannot be blocked by large clipboard contents.
    @discardableResult
    func catchIfChanged() -> Bool {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != handledChangeCount else { return false }
        handledChangeCount = pasteboard.changeCount
        let sourceAppName = NSWorkspace.shared.frontmostApplication?.localizedName

        let urls = PasteboardFileURLReader.read(from: pasteboard)
        if !urls.isEmpty {
            enqueue(.files(urls, sourceAppName: sourceAppName))
            return true
        }

        if let png = pasteboard.data(forType: Self.pngPasteboardType), !png.isEmpty {
            enqueue(.image(png, source: .png, sourceAppName: sourceAppName))
            return true
        }
        if let tiff = pasteboard.data(forType: .tiff), !tiff.isEmpty {
            enqueue(.image(tiff, source: .tiff, sourceAppName: sourceAppName))
            return true
        }

        guard let rawText = pasteboard.string(forType: .string) else { return false }
        enqueue(.text(rawText, sourceAppName: sourceAppName))
        return true
    }

    private func enqueue(_ work: CaptureWork) {
        pendingCaptures.append(work)
        startNextCaptureIfNeeded()
    }

    private func startNextCaptureIfNeeded() {
        guard captureProcessingTask == nil, !pendingCaptures.isEmpty else { return }
        let work = pendingCaptures.removeFirst()
        captureProcessingTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            await self.process(work)
            self.captureProcessingTask = nil
            self.startNextCaptureIfNeeded()
        }
    }

    private func process(_ work: CaptureWork) async {
        switch work {
        case .files(let urls, let sourceAppName):
            let paths = urls.map(\.path)
            let fingerprint = await Task.detached(priority: .utility) {
                Self.fingerprint(paths: paths)
            }.value
            let now = ProcessInfo.processInfo.systemUptime
            guard fingerprint != lastCapturedFilesFingerprint
                    || now - lastCapturedFilesAt >= Self.duplicateSuppressionInterval
            else { return }
            lastCapturedFilesFingerprint = fingerprint
            lastCapturedFilesAt = now
            await model.captureClipboardFilesAsync(urls, sourceAppName: sourceAppName)

        case .image(let rawData, let source, let sourceAppName):
            guard let imageData = await Task.detached(priority: .utility, operation: {
                ClipboardImageNormalizer.pngData(from: rawData, source: source)
            }).value else { return }

            let fingerprint = await Task.detached(priority: .utility) {
                Self.fingerprint(data: imageData)
            }.value
            let now = ProcessInfo.processInfo.systemUptime
            guard fingerprint != lastCapturedImageFingerprint
                    || now - lastCapturedImageAt >= Self.duplicateSuppressionInterval
            else { return }
            lastCapturedImageFingerprint = fingerprint
            lastCapturedImageAt = now
            await model.captureClipboardImageDataAsync(imageData, sourceAppName: sourceAppName)

        case .text(let rawText, let sourceAppName):
            let normalized = await Task.detached(priority: .utility) {
                let text = Self.normalizedClipboardText(rawText)
                return (text, Self.fingerprint(text: text))
            }.value
            guard !normalized.0.isEmpty else { return }

            let now = ProcessInfo.processInfo.systemUptime
            guard normalized.1 != lastCapturedTextFingerprint
                    || now - lastCapturedTextAt >= Self.duplicateSuppressionInterval
            else { return }
            lastCapturedTextFingerprint = normalized.1
            lastCapturedTextAt = now
            await model.captureClipboardTextAsync(normalized.0, sourceAppName: sourceAppName)
        }
    }

    func copyFromApp(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        handledChangeCount = pasteboard.changeCount
    }

    /// Managed clipboard images are stored as PNG. Copy the encoded bytes directly instead of
    /// decoding to NSImage -> TIFF -> PNG again on MainActor.
    @discardableResult
    func copyImageFile(_ path: String) -> Bool {
        guard let png = try? Data(contentsOf: URL(fileURLWithPath: path)), !png.isEmpty else {
            return false
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(png, forType: Self.pngPasteboardType)
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

    private nonisolated static func normalizedClipboardText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func fingerprint(text: String) -> ContentFingerprint {
        var hasher = Hasher()
        hasher.combine(text)
        return ContentFingerprint(
            digest: hasher.finalize(),
            byteCount: text.utf8.count,
            itemCount: 1
        )
    }

    private nonisolated static func fingerprint(data: Data) -> ContentFingerprint {
        var hasher = Hasher()
        hasher.combine(data)
        return ContentFingerprint(
            digest: hasher.finalize(),
            byteCount: data.count,
            itemCount: 1
        )
    }

    private nonisolated static func fingerprint(paths: [String]) -> ContentFingerprint {
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

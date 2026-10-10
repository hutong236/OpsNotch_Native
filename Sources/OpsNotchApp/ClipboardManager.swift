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

        /// Count retained payload bytes, not only the number of pending tasks.
        /// Paths and text are stored in UTF-8 once normalized; this conservative
        /// estimate is sufficient to pause incoming clipboard reads under load.
        var estimatedBytes: Int {
            switch self {
            case .files(let urls, _):
                return urls.reduce(0) { total, url in
                    let bytes = url.path.utf8.count
                    return bytes > Int.max - total ? Int.max : total + bytes
                }
            case .image(let data, _, _):
                return data.count
            case .text(let text, _):
                return text.utf8.count
            }
        }
    }

    private struct BufferedCapture {
        let work: CaptureWork
        let estimatedBytes: Int
    }

    private let model: AppModel
    private let pasteboard: NSPasteboard
    private let imageFileLoader: @Sendable (String) -> Data?
    /// Newer copies must win even when an older disk read completes afterward.
    private var imageCopyGeneration: UInt64 = 0
    private var handledChangeCount: Int
    private var monitorTask: Task<Void, Never>?
    private var captureProcessingTask: Task<Void, Never>?
    private var pendingCaptures: [BufferedCapture] = []
    /// Includes the currently processing capture (not just the pending array).
    private var outstandingCaptureCount = 0
    private var outstandingCaptureBytes = 0
    private var lastCapturedTextFingerprint: ContentFingerprint?
    private var lastCapturedTextAt: TimeInterval = 0
    private var lastCapturedFilesFingerprint: ContentFingerprint?
    private var lastCapturedFilesAt: TimeInterval = 0
    private var lastCapturedImageFingerprint: ContentFingerprint?
    private var lastCapturedImageAt: TimeInterval = 0
    var panelVisibleProvider: (() -> Bool)?

    init(
        model: AppModel,
        pasteboard: NSPasteboard = .general,
        imageFileLoader: @escaping @Sendable (String) -> Data? = ClipboardImageFileLoader.readPNG
    ) {
        self.model = model
        self.pasteboard = pasteboard
        self.imageFileLoader = imageFileLoader
        self.handledChangeCount = pasteboard.changeCount
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
        let pasteboard = self.pasteboard
        guard pasteboard.changeCount != handledChangeCount else { return false }
        // Avoid data(forType:) and NSString materialization while previous
        // snapshots are consuming the memory budget. Do NOT acknowledge this
        // changeCount: the newest clipboard contents will be retried once the
        // asynchronous capture pipeline makes room.
        guard ClipboardCaptureQueueBudget.shouldReadNextChange(
            outstandingItemCount: outstandingCaptureCount,
            outstandingByteCount: outstandingCaptureBytes
        ) else { return false }
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
        let bytes = work.estimatedBytes
        outstandingCaptureBytes = bytes > Int.max - outstandingCaptureBytes
            ? Int.max : outstandingCaptureBytes + bytes
        outstandingCaptureCount += 1
        pendingCaptures.append(BufferedCapture(work: work, estimatedBytes: bytes))
        startNextCaptureIfNeeded()
    }

    private func finishedProcessing(bytes: Int) {
        outstandingCaptureCount = max(0, outstandingCaptureCount - 1)
        outstandingCaptureBytes = max(0, outstandingCaptureBytes - bytes)
    }

    private func startNextCaptureIfNeeded() {
        guard captureProcessingTask == nil, !pendingCaptures.isEmpty else { return }
        let buffered = pendingCaptures.removeFirst()
        captureProcessingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if !Task.isCancelled {
                await self.process(buffered.work)
            }
            self.finishedProcessing(bytes: buffered.estimatedBytes)
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
        invalidatePendingImageCopies()
        let pasteboard = self.pasteboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        handledChangeCount = pasteboard.changeCount
    }

    /// Disk I/O runs off MainActor; only publication to NSPasteboard happens
    /// on MainActor. The completion fires once, after the clipboard is updated.
    /// Later copy actions (or an external pasteboard change) supersede a stale
    /// read so a slow image cannot overwrite more recent clipboard content.
    func copyImageFile(_ path: String, completion: @escaping @MainActor (Bool) -> Void) {
        invalidatePendingImageCopies()
        let generation = imageCopyGeneration
        let initialChangeCount = pasteboard.changeCount
        let loader = imageFileLoader

        Task { @MainActor [weak self] in
            let png = await Task.detached(priority: .userInitiated) {
                loader(path)
            }.value

            guard let self,
                  generation == self.imageCopyGeneration,
                  self.pasteboard.changeCount == initialChangeCount,
                  let png, !png.isEmpty else {
                completion(false)
                return
            }

            self.pasteboard.clearContents()
            let succeeded = self.pasteboard.setData(
                png, forType: Self.pngPasteboardType
            )
            self.handledChangeCount = self.pasteboard.changeCount
            completion(succeeded)
        }
    }

    private func invalidatePendingImageCopies() {
        imageCopyGeneration &+= 1
    }

    func copyPayload(_ payload: ShelfCopyPayload) {
        invalidatePendingImageCopies()
        let pasteboard = self.pasteboard
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
        invalidatePendingImageCopies()
        handledChangeCount = pasteboard.changeCount
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

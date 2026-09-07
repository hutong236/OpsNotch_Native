#if os(macOS)
import AppKit
import OpsNotchCore

/// 统一解析系统 Drag Pasteboard。File Promise 必须在 performDragOperation 调用栈中立即启动接收，
/// 因此这里保持同步入口；真正文件写入在独立 OperationQueue 中完成。
@MainActor
final class DropPayloadResolver {
    static let shared = DropPayloadResolver()

    private var activePromiseQueues: [UUID: OperationQueue] = [:]
    private let fileManager = FileManager.default

    private init() {}

    static var promisePasteboardTypes: [NSPasteboard.PasteboardType] {
        NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
    }

    static let imagePasteboardTypes: [NSPasteboard.PasteboardType] = [
        NSPasteboard.PasteboardType("public.png"),
        NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.heic"),
        NSPasteboard.PasteboardType("public.tiff"),
    ]

    static let richTextPasteboardTypes: [NSPasteboard.PasteboardType] = [
        NSPasteboard.PasteboardType("public.rtf"),
    ]

    static var extraPasteboardTypes: [NSPasteboard.PasteboardType] {
        promisePasteboardTypes + imagePasteboardTypes + richTextPasteboardTypes
    }

    static func canRead(_ pasteboard: NSPasteboard) -> Bool {
        hasFilePromiseType(pasteboard)
            || hasImageDataType(pasteboard)
            || hasRichTextType(pasteboard)
            || NativeDropPayload.canRead(pasteboard)
    }

    static func hasFilePromiseType(_ pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.types else { return false }
        let readable = Set(NSFilePromiseReceiver.readableDraggedTypes)
        return types.contains { readable.contains($0.rawValue) }
    }

    static func hasImageDataType(_ pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.types else { return false }
        let accepted = Set(imagePasteboardTypes)
        return types.contains { accepted.contains($0) }
    }

    static func hasRichTextType(_ pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.types else { return false }
        let accepted = Set(richTextPasteboardTypes)
        return types.contains { accepted.contains($0) }
    }

    func cleanupStaleStaging(rootURL: URL) {
        guard activePromiseQueues.isEmpty else { return }
        let stagingRoot = stagingRootURL(rootURL: rootURL)
        guard fileManager.fileExists(atPath: stagingRoot.path) else { return }
        do {
            try fileManager.removeItem(at: stagingRoot)
            dropLog.info("file promise stale staging cleaned")
        } catch {
            dropLog.error("file promise stale staging cleanup failed")
        }
    }

    /// 首选入口：必须从 NSDraggingDestination.performDragOperation 内调用。
    func performDrop(
        from draggingInfo: NSDraggingInfo,
        in destinationView: NSView,
        onPromiseStarted: () -> Void,
        handleImmediate: (NativeDropPayload) -> Bool,
        handlePromised: @escaping ([URL]) -> Void
    ) -> Bool {
        let pasteboard = draggingInfo.draggingPasteboard
        let promised = filePromiseReceivers(from: draggingInfo, in: destinationView)
        if !promised.isEmpty {
            return beginReceiving(promised, onPromiseStarted: onPromiseStarted, completion: handlePromised)
        }
        return performNonItemDrop(
            from: pasteboard,
            onPromiseStarted: onPromiseStarted,
            handleImmediate: handleImmediate,
            handlePromised: handlePromised
        )
    }

    /// 兼容 ShelfDropContainerView 的 pasteboard 入口。
    func performDrop(
        from pasteboard: NSPasteboard,
        onPromiseStarted: () -> Void,
        handleImmediate: (NativeDropPayload) -> Bool,
        handlePromised: @escaping ([URL]) -> Void
    ) -> Bool {
        if let promised = pasteboard.readObjects(
            forClasses: [NSFilePromiseReceiver.self],
            options: nil
        ) as? [NSFilePromiseReceiver], !promised.isEmpty {
            return beginReceiving(promised, onPromiseStarted: onPromiseStarted, completion: handlePromised)
        }
        return performNonItemDrop(
            from: pasteboard,
            onPromiseStarted: onPromiseStarted,
            handleImmediate: handleImmediate,
            handlePromised: handlePromised
        )
    }

    private func performNonItemDrop(
        from pasteboard: NSPasteboard,
        onPromiseStarted: () -> Void,
        handleImmediate: (NativeDropPayload) -> Bool,
        handlePromised: ([URL]) -> Void
    ) -> Bool {
        // 先读 pasteboard 明确声明的 fileURL/path。不能先用泛型 NSURL object reader，
        // 否则文件内容 flavor 可能被 AppKit 物化成 /tmp/... 并被错误持久化为源路径。
        if let filePayload = readFilePayload(from: pasteboard) {
            return handleImmediate(filePayload)
        }

        if let image = readableImageData(from: pasteboard) {
            return materializeImage(
                image,
                onPromiseStarted: onPromiseStarted,
                completion: handlePromised
            )
        }

        if let payload = NativeDropPayload.read(from: pasteboard) {
            return handleImmediate(payload)
        }

        if let richText = readRichText(from: pasteboard) {
            return handleImmediate(.text(richText))
        }

        return false
    }

    private func filePromiseReceivers(from draggingInfo: NSDraggingInfo, in destinationView: NSView) -> [NSFilePromiseReceiver] {
        var receivers: [NSFilePromiseReceiver] = []
        draggingInfo.enumerateDraggingItems(
            options: [],
            for: destinationView,
            classes: [NSFilePromiseReceiver.self],
            searchOptions: [:]
        ) { item, _, _ in
            if let receiver = item.item as? NSFilePromiseReceiver {
                receivers.append(receiver)
            }
        }

        if !receivers.isEmpty { return receivers }
        return draggingInfo.draggingPasteboard.readObjects(
            forClasses: [NSFilePromiseReceiver.self],
            options: nil
        ) as? [NSFilePromiseReceiver] ?? []
    }

    private func readFilePayload(from pasteboard: NSPasteboard) -> NativeDropPayload? {
        let urls = PasteboardFileURLReader.read(from: pasteboard)
        return urls.isEmpty ? nil : .files(urls)
    }

    private struct ImageDataPayload {
        let data: Data
        let fileExtension: String
    }

    private func readableImageData(from pasteboard: NSPasteboard) -> ImageDataPayload? {
        let candidates: [(NSPasteboard.PasteboardType, String)] = [
            (NSPasteboard.PasteboardType("public.png"), "png"),
            (NSPasteboard.PasteboardType("public.jpeg"), "jpg"),
            (NSPasteboard.PasteboardType("public.heic"), "heic"),
            (NSPasteboard.PasteboardType("public.tiff"), "tiff"),
        ]
        for (type, ext) in candidates {
            if let data = pasteboard.data(forType: type), !data.isEmpty {
                return ImageDataPayload(data: data, fileExtension: ext)
            }
        }
        return nil
    }

    private func readRichText(from pasteboard: NSPasteboard) -> String? {
        let type = NSPasteboard.PasteboardType("public.rtf")
        guard let data = pasteboard.data(forType: type),
              let value = NSAttributedString(rtf: data, documentAttributes: nil)?.string
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    private func materializeImage(
        _ image: ImageDataPayload,
        onPromiseStarted: () -> Void,
        completion: ([URL]) -> Void
    ) -> Bool {
        let sessionID = UUID()
        let stagingURL = stagingRootURL()
            .appendingPathComponent(sessionID.uuidString, isDirectory: true)
        let fileURL = stagingURL.appendingPathComponent("Dragged Image.\(image.fileExtension)")

        do {
            try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
            try image.data.write(to: fileURL, options: .atomic)
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            dropLog.error("image drag materialization failed")
            return false
        }

        onPromiseStarted()
        dropLog.info("image drag materialized")
        completion([fileURL])
        try? fileManager.removeItem(at: stagingURL)
        return true
    }

    private func beginReceiving(
        _ receivers: [NSFilePromiseReceiver],
        onPromiseStarted: () -> Void,
        completion: @escaping ([URL]) -> Void
    ) -> Bool {
        let sessionID = UUID()
        let stagingURL = stagingRootURL()
            .appendingPathComponent(sessionID.uuidString, isDirectory: true)

        do {
            try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        } catch {
            dropLog.error("file promise staging create failed")
            return false
        }

        let queue = OperationQueue()
        queue.name = "lab.hutong.opsnotch.file-promise.\(sessionID.uuidString)"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 2
        activePromiseQueues[sessionID] = queue

        let accumulator = PromiseAccumulator()
        onPromiseStarted()
        dropLog.info("file promise receive started receivers=\(receivers.count, privacy: .public)")

        var expectedCallbacks = 0
        for receiver in receivers {
            receiver.receivePromisedFiles(
                atDestination: stagingURL,
                options: [:],
                operationQueue: queue
            ) { [weak self] fileURL, error in
                guard let self else { return }
                if let snapshot = accumulator.record(fileURL: fileURL, error: error) {
                    Task { @MainActor in
                        self.finishPromiseSession(
                            sessionID: sessionID,
                            stagingURL: stagingURL,
                            snapshot: snapshot,
                            completion: completion
                        )
                    }
                }
            }
            expectedCallbacks += max(receiver.fileNames.count, 1)
        }

        if let snapshot = accumulator.setExpectedCallbacks(expectedCallbacks) {
            finishPromiseSession(
                sessionID: sessionID,
                stagingURL: stagingURL,
                snapshot: snapshot,
                completion: completion
            )
        }
        return true
    }

    private func finishPromiseSession(
        sessionID: UUID,
        stagingURL: URL,
        snapshot: PromiseSnapshot,
        completion: ([URL]) -> Void
    ) {
        guard activePromiseQueues[sessionID] != nil else { return }
        dropLog.info(
            "file promise receive finished success=\(snapshot.urls.count, privacy: .public) failure=\(snapshot.failures, privacy: .public)"
        )

        completion(snapshot.urls)
        activePromiseQueues[sessionID] = nil
        try? fileManager.removeItem(at: stagingURL)
    }

    private func stagingRootURL() -> URL {
        stagingRootURL(rootURL: ShelfStoreService.defaultRootURL())
    }

    private func stagingRootURL(rootURL: URL) -> URL {
        rootURL.appendingPathComponent("drop-staging", isDirectory: true)
    }
}

private struct PromiseSnapshot {
    let urls: [URL]
    let failures: Int
}

private final class PromiseAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []
    private var failures = 0
    private var callbackCount = 0
    private var expectedCallbacks: Int?
    private var finished = false

    func record(fileURL: URL, error: Error?) -> PromiseSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return nil }
        callbackCount += 1
        if error == nil {
            urls.append(fileURL)
        } else {
            failures += 1
        }
        return finishIfReadyUnlocked()
    }

    func setExpectedCallbacks(_ count: Int) -> PromiseSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return nil }
        expectedCallbacks = max(1, count)
        return finishIfReadyUnlocked()
    }

    private func finishIfReadyUnlocked() -> PromiseSnapshot? {
        guard let expectedCallbacks, callbackCount >= expectedCallbacks else { return nil }
        finished = true
        return PromiseSnapshot(urls: urls, failures: failures)
    }
}
#endif

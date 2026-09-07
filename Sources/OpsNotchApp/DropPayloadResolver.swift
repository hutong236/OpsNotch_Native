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
        NSFilePromiseReceiver.readableDraggedTypes.map(NSPasteboard.PasteboardType.init)
    }

    static func canRead(_ pasteboard: NSPasteboard) -> Bool {
        hasFilePromiseType(pasteboard) || NativeDropPayload.canRead(pasteboard)
    }

    static func hasFilePromiseType(_ pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.types else { return false }
        let readable = Set(NSFilePromiseReceiver.readableDraggedTypes)
        return types.contains { readable.contains($0.rawValue) }
    }

    /// 必须从 NSDraggingDestination.performDragOperation 内调用。
    /// - Immediate payload: 同步调用 handleImmediate 并返回其结果。
    /// - File Promise: 在当前调用栈立即 receivePromisedFiles，异步完成后回主线程调用 handlePromised。
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

        guard let payload = NativeDropPayload.read(from: pasteboard) else { return false }
        return handleImmediate(payload)
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

        // Apple 要求 receivePromisedFiles 在 prepare/perform/concludeDragOperation 期间调用。
        // 所有 receiver 均在当前 performDragOperation 调用栈中启动。
        for receiver in receivers {
            receiver.receivePromisedFiles(
                atDestination: stagingURL,
                options: [:],
                operationQueue: queue
            ) { fileURL, error in
                accumulator.record(fileURL: fileURL, error: error)
            }
        }

        // 每个 session 使用自己的 queue；barrier 在本 session 先前提交的 promise 写入完成后汇总。
        queue.addBarrierBlock { [weak self] in
            let snapshot = accumulator.snapshot()
            Task { @MainActor in
                guard let self else { return }
                dropLog.info(
                    "file promise receive finished success=\(snapshot.urls.count, privacy: .public) failure=\(snapshot.failures, privacy: .public)"
                )

                // Promise 是临时产生的文件，没有可长期引用的源路径。调用方会以 copy 模式入柜；
                // handler 同步返回后即可清理 staging。
                completion(snapshot.urls)
                self.activePromiseQueues[sessionID] = nil
                try? self.fileManager.removeItem(at: stagingURL)
            }
        }
        return true
    }

    private func stagingRootURL() -> URL {
        ShelfStoreService.defaultRootURL()
            .appendingPathComponent("drop-staging", isDirectory: true)
    }
}

private final class PromiseAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []
    private var failures = 0

    func record(fileURL: URL, error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        if error == nil {
            urls.append(fileURL)
        } else {
            failures += 1
        }
    }

    func snapshot() -> (urls: [URL], failures: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (urls, failures)
    }
}
#endif

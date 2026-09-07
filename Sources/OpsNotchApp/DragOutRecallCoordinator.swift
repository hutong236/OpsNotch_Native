#if os(macOS)
import Foundation
import OpsNotchCore

/// Drag-out 的单步 Recall 存储。
///
/// 对 reference/text/url 等条目只需保存 ShelfItem 快照；对 storageMode=.copy 的条目，
/// 不能调用普通 remove（会直接删除 shelf-files/<id>）。这里先把受管目录同卷 rename 到
/// drag-out-recall/<session>/<id>，这样成功拖出后可从 Shelf 消费掉，同时仍能用 ⌘Z 恢复。
@MainActor
final class DragOutRecallCoordinator {
    static let shared = DragOutRecallCoordinator()

    private struct Entry {
        let item: ShelfItem
        let originalIndex: Int
    }

    private struct Record {
        let entries: [Entry]
        let stashURL: URL
    }

    private enum RecallError: LocalizedError {
        case missingManagedContent
        case restoreConflict

        var errorDescription: String? {
            switch self {
            case .missingManagedContent:
                return "Managed Shelf file is missing; drag-out cleanup was cancelled."
            case .restoreConflict:
                return "Could not restore the previous Shelf item because its managed location is already in use."
            }
        }
    }

    private let fileManager = FileManager.default
    private var record: Record?

    private init() {}

    /// 成功 drag session 后消费条目并保存一次 Recall。
    /// 调用方必须已过滤 pinned/Working Set 等受保护条目。
    func consume(items: [ShelfItem], store: ShelfStoreService) throws -> ShelfStore {
        guard !items.isEmpty else { return try store.load() }
        try discardPreviousRecall()

        var current = try store.load()
        let requestedIDs = Set(items.map(\.id))
        let entries = current.items.enumerated().compactMap { index, item -> Entry? in
            requestedIDs.contains(item.id) ? Entry(item: item, originalIndex: index) : nil
        }
        guard !entries.isEmpty else { return current }

        let sessionURL = recallRootURL(for: store)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: sessionURL, withIntermediateDirectories: true)

        var movedIDs: [UUID] = []
        do {
            for entry in entries where entry.item.storageMode == .copy {
                let source = managedDirectory(for: entry.item.id, store: store)
                guard fileManager.fileExists(atPath: source.path) else {
                    throw RecallError.missingManagedContent
                }
                let destination = sessionURL.appendingPathComponent(entry.item.id.uuidString, isDirectory: true)
                try fileManager.moveItem(at: source, to: destination)
                movedIDs.append(entry.item.id)
            }

            let ids = Set(entries.map { $0.item.id })
            current.items.removeAll { ids.contains($0.id) }
            current.settings.workingSetItemIDs.removeAll { ids.contains($0) }
            let saved = try store.save(current)
            record = Record(entries: entries, stashURL: sessionURL)
            return saved
        } catch {
            rollbackMoves(movedIDs, from: sessionURL, store: store)
            try? fileManager.removeItem(at: sessionURL)
            throw error
        }
    }

    /// 恢复最近一次被 drag-out 消费的条目。没有可恢复记录时返回 nil。
    func recall(store: ShelfStoreService) throws -> ShelfStore? {
        guard let record else { return nil }

        var current = try store.load()
        let existingIDs = Set(current.items.map(\.id))
        let entries = record.entries.filter { !existingIDs.contains($0.item.id) }
        if entries.isEmpty {
            try? fileManager.removeItem(at: record.stashURL)
            self.record = nil
            return current
        }

        var restoredManagedIDs: [UUID] = []
        do {
            for entry in entries where entry.item.storageMode == .copy {
                let source = record.stashURL.appendingPathComponent(entry.item.id.uuidString, isDirectory: true)
                let destination = managedDirectory(for: entry.item.id, store: store)
                guard fileManager.fileExists(atPath: source.path),
                      !fileManager.fileExists(atPath: destination.path) else {
                    throw RecallError.restoreConflict
                }
                try fileManager.moveItem(at: source, to: destination)
                restoredManagedIDs.append(entry.item.id)
            }

            // 尽量恢复原来在 Shelf 中的位置；期间若列表已有变化则 clamp 到当前范围。
            for entry in entries.sorted(by: { $0.originalIndex < $1.originalIndex }) {
                let index = min(max(entry.originalIndex, 0), current.items.count)
                current.items.insert(entry.item, at: index)
            }

            let saved = try store.save(current)
            try? fileManager.removeItem(at: record.stashURL)
            self.record = nil
            return saved
        } catch {
            // save/restore 失败时，把已经恢复的受管目录移回 stash，保留 Recall 可重试。
            for id in restoredManagedIDs.reversed() {
                let source = managedDirectory(for: id, store: store)
                let destination = record.stashURL.appendingPathComponent(id.uuidString, isDirectory: true)
                if fileManager.fileExists(atPath: source.path), !fileManager.fileExists(atPath: destination.path) {
                    try? fileManager.moveItem(at: source, to: destination)
                }
            }
            throw error
        }
    }

    /// Recall 只保证当前 App 会话的一步撤销；异常退出后残留的缓存下次启动直接清理。
    func cleanupStaleStorage(store: ShelfStoreService) {
        guard record == nil else { return }
        let root = recallRootURL(for: store)
        if fileManager.fileExists(atPath: root.path) {
            try? fileManager.removeItem(at: root)
        }
    }

    private func discardPreviousRecall() throws {
        guard let record else { return }
        if fileManager.fileExists(atPath: record.stashURL.path) {
            try fileManager.removeItem(at: record.stashURL)
        }
        self.record = nil
    }

    private func rollbackMoves(_ ids: [UUID], from sessionURL: URL, store: ShelfStoreService) {
        for id in ids.reversed() {
            let source = sessionURL.appendingPathComponent(id.uuidString, isDirectory: true)
            let destination = managedDirectory(for: id, store: store)
            if fileManager.fileExists(atPath: source.path), !fileManager.fileExists(atPath: destination.path) {
                try? fileManager.moveItem(at: source, to: destination)
            }
        }
    }

    private func recallRootURL(for store: ShelfStoreService) -> URL {
        store.rootURL.appendingPathComponent("drag-out-recall", isDirectory: true)
    }

    private func managedDirectory(for id: UUID, store: ShelfStoreService) -> URL {
        store.managedFilesURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }
}
#endif

import Foundation

public final class ShelfStoreService: @unchecked Sendable {
    /// 条目总数软上限。淘汰规则见 enforceItemLimit。
    public static let maxItems = 500

    public let rootURL: URL
    public let storeURL: URL
    public let managedFilesURL: URL

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.storeURL = rootURL.appendingPathComponent("shelf.json")
        self.managedFilesURL = rootURL.appendingPathComponent("shelf-files", isDirectory: true)
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.sortedKeys]
    }

    public static func defaultRootURL(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("lab.hutong.opsnotch", isDirectory: true)
    }

    public func load() throws -> ShelfStore {
        lock.lock(); defer { lock.unlock() }
        try ensureDirectories()
        guard fileManager.fileExists(atPath: storeURL.path) else {
            let store = ShelfStore()
            try writeUnlocked(store)
            return store
        }

        let data = try Data(contentsOf: storeURL)
        var store = try decodeCompatible(data)
        // 按需写盘:只有真实迁移或 TTL 清理才落盘,普通读取零写入。
        // Sensor 触发等高频路径依赖"读取无副作用",不能每次 load 都重写整个文件。
        let versionBeforeMigration = store.version
        migrate(&store)
        let didMigrate = store.version != versionBeforeMigration
        let expired = ShelfLogic.expiredIDs(items: store.items, settings: store.settings)
        var didExpire = false
        if !expired.isEmpty {
            store.items.removeAll { expired.contains($0.id) }
            for id in expired { try? removeManagedDirectory(id: id) }
            didExpire = true
        }
        normalizeWorkingSet(&store)
        if didMigrate || didExpire {
            try writeUnlocked(store)
        }
        return store
    }

    @discardableResult
    public func save(_ store: ShelfStore) throws -> ShelfStore {
        lock.lock(); defer { lock.unlock() }
        try ensureDirectories()
        var current = store
        current.version = ShelfStore.currentVersion
        normalizeWorkingSet(&current)
        enforceItemLimit(&current)
        try writeUnlocked(current)
        return current
    }

    @discardableResult
    public func addText(_ content: String, title: String? = nil) throws -> ShelfStore {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try load() }
        return try mutate { store in
            let displayTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? trimmed.split(separator: "\n", maxSplits: 1).first.map(String.init)?.prefixString(48)
                ?? "Text"
            store.items.append(ShelfItem(kind: .text, title: displayTitle, content: trimmed))
        }
    }

    @discardableResult
    public func addURL(_ value: String, title: String? = nil) throws -> ShelfStore {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SafeActionValidator.isHTTPURL(trimmed) else { throw ShelfStoreError.invalidURL }
        return try mutate { store in
            let fallback = URL(string: trimmed)?.host ?? trimmed
            store.items.append(ShelfItem(kind: .url, title: title?.nonEmpty ?? fallback, content: trimmed))
        }
    }

    @discardableResult
    public func addAction(title: String, content: String, kind: SafeActionKind) throws -> ShelfStore {
        guard let normalized = SafeActionValidator.normalizedActionContent(kind: kind, content: content)
        else { throw ShelfStoreError.unsafeAction }
        return try mutate { store in
            store.items.append(ShelfItem(kind: .action, title: title.nonEmpty ?? "Action", content: normalized, actionKind: kind))
        }
    }

    @discardableResult
    public func addPath(_ source: URL, mode: StorageMode, forcedKind: ShelfKind? = nil) throws -> ShelfStore {
        let values = try source.resourceValues(forKeys: [.isDirectoryKey, .nameKey])
        let kind: ShelfKind = forcedKind ?? ((values.isDirectory ?? false) ? .folder : .file)
        let id = UUID()
        let storedURL: URL
        if mode == .copy {
            let parent = managedFilesURL.appendingPathComponent(id.uuidString, isDirectory: true)
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            let destination = parent.appendingPathComponent(source.lastPathComponent, isDirectory: values.isDirectory ?? false)
            try fileManager.copyItem(at: source, to: destination)
            storedURL = destination
        } else {
            storedURL = source
        }

        return try mutate { store in
            let title = source.deletingPathExtension().lastPathComponent.nonEmpty ?? source.lastPathComponent
            store.items.append(ShelfItem(
                id: id,
                kind: kind,
                title: title,
                content: storedURL.path,
                storageMode: mode,
                fileExtension: source.pathExtension.nonEmpty
            ))
        }
    }

    @discardableResult
    public func addApplication(_ url: URL) throws -> ShelfStore {
        try addPath(url, mode: .reference, forcedKind: .application)
    }

    @discardableResult
    public func setPinned(id: UUID, pinned: Bool) throws -> ShelfStore {
        try mutate { store in
            guard let index = store.items.firstIndex(where: { $0.id == id }) else { return }
            store.items[index].pinned = pinned
            store.items[index].updatedAt = ShelfClock.now()
        }
    }

    @discardableResult
    public func edit(id: UUID, title: String, content: String? = nil) throws -> ShelfStore {
        try mutate { store in
            guard let index = store.items.firstIndex(where: { $0.id == id }) else { return }
            store.items[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? store.items[index].title
            if let content {
                switch store.items[index].kind {
                case .text:
                    let value = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty { store.items[index].content = value }
                case .url:
                    if let normalized = SafeActionValidator.normalizedActionContent(kind: .openURL, content: content) {
                        store.items[index].content = normalized
                    }
                case .action:
                    if let kind = store.items[index].actionKind,
                       let normalized = SafeActionValidator.normalizedActionContent(kind: kind, content: content) {
                        store.items[index].content = normalized
                    }
                default: break
                }
            }
            store.items[index].updatedAt = ShelfClock.now()
        }
    }

    @discardableResult
    public func touch(id: UUID) throws -> ShelfStore {
        try mutate { store in
            guard let index = store.items.firstIndex(where: { $0.id == id }) else { return }
            store.items[index].updatedAt = ShelfClock.now()
        }
    }

    /// V2：成功使用 Shelf 条目后累计频率并记录最近使用时间。
    @discardableResult
    public func recordUse(id: UUID, now: UInt64 = ShelfClock.now()) throws -> ShelfStore {
        try mutate { store in
            guard let index = store.items.firstIndex(where: { $0.id == id }) else { return }
            store.items[index].useCount &+= 1
            store.items[index].lastUsedAt = now
            // 保留 V1 行为：一次成功取回也会使条目在最近列表中上浮。
            store.items[index].updatedAt = now
        }
    }

    @discardableResult
    public func remove(ids: Set<UUID>) throws -> ShelfStore {
        try mutate { store in
            let copies = store.items.filter { ids.contains($0.id) && $0.storageMode == .copy }.map(\.id)
            store.items.removeAll { ids.contains($0.id) }
            store.settings.workingSetItemIDs.removeAll { ids.contains($0) }
            for id in copies { try? removeManagedDirectory(id: id) }
        }
    }

    @discardableResult
    public func clearRecent() throws -> ShelfStore {
        let value = try load()
        let workingSetIDs = Set(value.settings.workingSetItemIDs)
        let ids = Set(value.items.filter { !$0.pinned && !workingSetIDs.contains($0.id) }.map(\.id))
        return try remove(ids: ids)
    }

    @discardableResult
    public func updateSettings(_ settings: ShelfSettings) throws -> ShelfStore {
        try mutate { store in store.settings = settings }
    }

    /// 模块内可见(而非 private),供同模块扩展(如剪贴板捕获入口)复用单趟读改写管线。
    func mutate(_ body: (inout ShelfStore) throws -> Void) throws -> ShelfStore {
        lock.lock(); defer { lock.unlock() }
        try ensureDirectories()
        var store: ShelfStore
        if fileManager.fileExists(atPath: storeURL.path) {
            store = try decodeCompatible(Data(contentsOf: storeURL))
        } else {
            store = ShelfStore()
        }
        migrate(&store)
        try body(&store)
        normalizeWorkingSet(&store)
        enforceItemLimit(&store)
        store.version = ShelfStore.currentVersion
        try writeUnlocked(store)
        return store
    }

    /// 条目总数软上限:超过 maxItems 时淘汰最旧的未置顶且不在 Working Set 的条目,
    /// 阻止捕获类写入让 shelf.json 无界膨胀。置顶与 Working Set 条目永不自动淘汰。
    private func enforceItemLimit(_ store: inout ShelfStore) {
        let overflow = store.items.count - Self.maxItems
        guard overflow > 0 else { return }
        let protectedIDs = Set(store.settings.workingSetItemIDs)
        let evictIDs = Set(store.items
            .filter { !$0.pinned && !protectedIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
                return lhs.createdAt < rhs.createdAt
            }
            .prefix(overflow)
            .map(\.id))
        let managedCopies = store.items.filter { evictIDs.contains($0.id) && $0.storageMode == .copy }.map(\.id)
        store.items.removeAll { evictIDs.contains($0.id) }
        for id in managedCopies { try? removeManagedDirectory(id: id) }
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: managedFilesURL, withIntermediateDirectories: true)
    }

    private func decodeCompatible(_ data: Data) throws -> ShelfStore {
        if let current = try? decoder.decode(ShelfStore.self, from: data) { return current }
        if let legacyItems = try? decoder.decode([ShelfItem].self, from: data) {
            return ShelfStore(version: 1, items: legacyItems, settings: .init())
        }
        throw ShelfStoreError.invalidStore
    }

    private func migrate(_ store: inout ShelfStore) {
        if store.version < ShelfStore.currentVersion {
            if store.version > 0 && store.version < 6 && store.settings.displayTarget == .mouse {
                store.settings.displayTarget = .all
            }
            store.version = ShelfStore.currentVersion
        }
        normalizeWorkingSet(&store)
    }

    private func normalizeWorkingSet(_ store: inout ShelfStore) {
        let validIDs = Set(store.items.map(\.id))
        var seen = Set<UUID>()
        var normalized: [UUID] = []
        for id in store.settings.workingSetItemIDs {
            guard validIDs.contains(id), !seen.contains(id) else { continue }
            seen.insert(id)
            normalized.append(id)
            if normalized.count >= 64 { break }
        }
        store.settings.workingSetItemIDs = normalized
    }

    private func writeUnlocked(_ store: ShelfStore) throws {
        let data = try encoder.encode(store)
        let tmp = storeURL.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        if fileManager.fileExists(atPath: storeURL.path) {
            try fileManager.removeItem(at: storeURL)
        }
        try fileManager.moveItem(at: tmp, to: storeURL)
    }

    private func removeManagedDirectory(id: UUID) throws {
        let directory = managedFilesURL.appendingPathComponent(id.uuidString, isDirectory: true)
        if fileManager.fileExists(atPath: directory.path) { try fileManager.removeItem(at: directory) }
    }
}

public enum ShelfStoreError: LocalizedError {
    case invalidStore
    case invalidURL
    case unsafeAction

    public var errorDescription: String? {
        switch self {
        case .invalidStore: return "Shelf data is not a supported format."
        case .invalidURL: return "Only http/https URLs are supported."
        case .unsafeAction: return "Safe Action only supports a local absolute path or http/https URL."
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
    func prefixString(_ maxLength: Int) -> String { String(prefix(maxLength)) }
}

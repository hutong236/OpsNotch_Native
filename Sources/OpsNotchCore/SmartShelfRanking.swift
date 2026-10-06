import Foundation

public enum SemanticKind: String, Codable, CaseIterable, Sendable {
    case file
    case folder
    case application
    case url
    case ipv4
    case ssh
    case command
    case path
    case text
    case action
}

public enum AppContextKind: String, Codable, CaseIterable, Sendable {
    case finder
    case terminal
    case browser
    case generic
}

public enum ShelfSemantic {
    private static let commandPrefixes: Set<String> = [
        "kubectl", "docker", "docker-compose", "podman", "git", "ssh", "scp", "sftp", "rsync",
        "ping", "traceroute", "curl", "wget", "helm", "terraform", "ansible", "ansible-playbook",
        "systemctl", "journalctl", "brew", "npm", "npx", "pnpm", "yarn", "python", "python3", "pip",
        "pip3", "swift", "cargo", "go", "make", "cmake", "grep", "sed", "awk", "tail", "head",
        "cat", "less", "find", "ls", "cd", "mkdir", "cp", "mv", "rm", "chmod", "chown"
    ]

    /// SwiftUI 会在一次布局/重绘周期内多次读取同一条目的语义类型。
    /// 对原始文本做有界缓存，避免反复执行 split/contains/Unicode 字符分类。
    private static let textKindCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 1_024
        cache.totalCostLimit = 2 * 1_024 * 1_024
        return cache
    }()

    public static func kind(for item: ShelfItem) -> SemanticKind {
        switch item.kind {
        case .file: return .file
        case .folder: return .folder
        case .application: return .application
        case .url: return .url
        case .action:
            switch item.actionKind {
            case .openPath: return .path
            case .openURL: return .url
            case nil: return .action
            }
        case .text:
            return kind(forText: item.content)
        }
    }

    public static func kind(forText raw: String) -> SemanticKind {
        let cacheKey = raw as NSString
        if let cachedRaw = textKindCache.object(forKey: cacheKey),
           let cached = SemanticKind(rawValue: cachedRaw as String) {
            return cached
        }

        let kind = uncachedKind(forText: raw)
        textKindCache.setObject(
            kind.rawValue as NSString,
            forKey: cacheKey,
            cost: raw.utf8.count
        )
        return kind
    }

    private static func uncachedKind(forText raw: String) -> SemanticKind {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .text }
        let lower = value.lowercased()

        if SafeActionValidator.isHTTPURL(value) { return .url }
        if lower.hasPrefix("ssh ") || lower.hasPrefix("ssh\t") { return .ssh }
        if isIPv4(value) { return .ipv4 }
        if isLocalPath(value) { return .path }

        let firstToken = lower
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map(String.init) ?? ""
        if commandPrefixes.contains(firstToken) { return .command }
        if value.contains(" | ") || value.contains(" && ") || value.contains(" || ") { return .command }
        return .text
    }

    public static func isIPv4(_ raw: String) -> Bool {
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard !part.isEmpty,
                  part.count <= 3,
                  part.allSatisfy({ $0.isNumber }),
                  let value = Int(part) else { return false }
            return (0...255).contains(value)
        }
    }

    private static func isLocalPath(_ value: String) -> Bool {
        value.hasPrefix("/") || value.hasPrefix("~/") || value.hasPrefix("file://")
    }
}

private final class SmartShelfRankingCache: @unchecked Sendable {
    private struct Entry {
        let items: [ShelfItem]
        let query: String
        let kindFilter: ShelfKindFilter
        let appContext: AppContextKind
        let now: UInt64
        let result: [ShelfItem]
    }

    private let lock = NSLock()
    private var entries: [Entry] = []
    private var hits = 0
    private var misses = 0
    private let limit = 12

    func value(
        for items: [ShelfItem],
        query: String,
        kindFilter: ShelfKindFilter,
        appContext: AppContextKind,
        now: UInt64
    ) -> [ShelfItem]? {
        lock.lock()
        defer { lock.unlock() }

        guard let index = entries.firstIndex(where: {
            $0.now == now
                && $0.query == query
                && $0.kindFilter == kindFilter
                && $0.appContext.rawValue == appContext.rawValue
                && $0.items == items
        }) else {
            misses += 1
            return nil
        }

        let entry = entries.remove(at: index)
        entries.insert(entry, at: 0)
        hits += 1
        return entry.result
    }

    func insert(
        _ result: [ShelfItem],
        for items: [ShelfItem],
        query: String,
        kindFilter: ShelfKindFilter,
        appContext: AppContextKind,
        now: UInt64
    ) {
        lock.lock()
        defer { lock.unlock() }

        entries.removeAll(where: {
            $0.now == now
                && $0.query == query
                && $0.kindFilter == kindFilter
                && $0.appContext.rawValue == appContext.rawValue
                && $0.items == items
        })
        entries.insert(
            Entry(
                items: items,
                query: query,
                kindFilter: kindFilter,
                appContext: appContext,
                now: now,
                result: result
            ),
            at: 0
        )
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
    }

    func reset() {
        lock.lock()
        entries.removeAll(keepingCapacity: true)
        hits = 0
        misses = 0
        lock.unlock()
    }

    func stats() -> (hits: Int, misses: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (hits, misses)
    }
}

public enum SmartShelfRanking {
    private static let cache = SmartShelfRankingCache()

    public static func ordered(
        _ items: [ShelfItem],
        query: String = "",
        kindFilter: ShelfKindFilter = .all,
        appContext: AppContextKind = .generic,
        now: UInt64 = ShelfClock.now()
    ) -> [ShelfItem] {
        if let cached = cache.value(
            for: items,
            query: query,
            kindFilter: kindFilter,
            appContext: appContext,
            now: now
        ) {
            return cached
        }

        let filtered = items.filter { ShelfLogic.matches($0, query: query, kindFilter: kindFilter) }
        guard filtered.count > 1 else {
            cache.insert(
                filtered,
                for: items,
                query: query,
                kindFilter: kindFilter,
                appContext: appContext,
                now: now
            )
            return filtered
        }

        // “最新加入”使用 createdAt，而不是 updatedAt / lastUsedAt：
        // 编辑、复制取回或使用次数变化不能把旧条目伪装成刚加入的条目。
        // createdAt 只有秒级精度；同秒加入时保留输入数组中靠后的条目为最新，
        // 与 ShelfStoreService 新增条目 append 到数组尾部的行为一致。
        let newestIndex = filtered.indices.max { lhs, rhs in
            let left = filtered[lhs]
            let right = filtered[rhs]
            if left.createdAt != right.createdAt { return left.createdAt < right.createdAt }
            return lhs < rhs
        }!
        let newest = filtered[newestIndex]

        var remaining = filtered
        remaining.remove(at: newestIndex)
        let result = [newest] + smartOrdered(
            remaining,
            query: query,
            appContext: appContext,
            now: now
        )
        cache.insert(
            result,
            for: items,
            query: query,
            kindFilter: kindFilter,
            appContext: appContext,
            now: now
        )
        return result
    }

    /// 最新加入条目之外的内容继续沿用原有 SmartScore 排序。
    private static func smartOrdered(
        _ items: [ShelfItem],
        query: String,
        appContext: AppContextKind,
        now: UInt64
    ) -> [ShelfItem] {
        // 评分预计算:每条目只算一次 score,排序比较器不再重复全文评分。
        // 排序键(score → updatedAt → createdAt → id)与逐次评分的旧实现逐字段一致。
        items
            .map { item in
                (item: item, score: score(item: item, query: query, appContext: appContext, now: now))
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                if lhs.item.updatedAt != rhs.item.updatedAt { return lhs.item.updatedAt > rhs.item.updatedAt }
                if lhs.item.createdAt != rhs.item.createdAt { return lhs.item.createdAt > rhs.item.createdAt }
                return lhs.item.id.uuidString < rhs.item.id.uuidString
            }
            .map(\.item)
    }

    public static func score(
        item: ShelfItem,
        query: String = "",
        appContext: AppContextKind = .generic,
        now: UInt64 = ShelfClock.now()
    ) -> Double {
        queryScore(item: item, query: query)
            + recencyScore(timestamp: item.updatedAt, now: now, maximum: 120)
            + frequencyScore(item.useCount)
            + recencyScore(timestamp: item.lastUsedAt, now: now, maximum: 80)
            + contextScore(semantic: ShelfSemantic.kind(for: item), appContext: appContext)
    }

    private static func queryScore(item: ShelfItem, query: String) -> Double {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return 0 }
        let title = item.title.lowercased()
        let content = item.content.lowercased()

        // 每个匹配等级的间隔都大于 recency + frequency + app-context 的最大总贡献，
        // 保证用户显式搜索在“最新加入”保留位之后，仍优先于环境推荐。
        if title == q || content == q { return 4_000 }
        if title.hasPrefix(q) || content.hasPrefix(q) { return 3_000 }
        if title.contains(q) { return 2_000 }
        if content.contains(q) { return 1_000 }
        return 0
    }

    private static func recencyScore(timestamp: UInt64, now: UInt64, maximum: Double) -> Double {
        guard timestamp > 0 else { return 0 }
        let ageSeconds = now > timestamp ? now - timestamp : 0
        let ageHours = Double(ageSeconds) / 3_600.0
        // 72 小时内平滑衰减，之后不再继续贡献。
        let factor = max(0, 1.0 - min(ageHours, 72.0) / 72.0)
        return maximum * factor
    }

    private static func frequencyScore(_ useCount: UInt64) -> Double {
        guard useCount > 0 else { return 0 }
        return min(log2(Double(useCount) + 1.0) * 18.0, 72.0)
    }

    public static func contextScore(semantic: SemanticKind, appContext: AppContextKind) -> Double {
        switch appContext {
        case .finder:
            switch semantic {
            case .file, .folder, .application: return 90
            case .path: return 72
            default: return 0
            }
        case .terminal:
            switch semantic {
            case .ssh, .command: return 90
            case .ipv4: return 82
            case .path: return 64
            case .file, .folder: return 28
            default: return 0
            }
        case .browser:
            switch semantic {
            case .url: return 90
            case .text: return 42
            default: return 0
            }
        case .generic:
            return 0
        }
    }

    static func _resetCacheForTesting() {
        cache.reset()
    }

    static func _cacheStatsForTesting() -> (hits: Int, misses: Int) {
        cache.stats()
    }
}

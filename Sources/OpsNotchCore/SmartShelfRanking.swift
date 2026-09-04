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

public enum SmartShelfRanking {
    public static func ordered(
        _ items: [ShelfItem],
        query: String = "",
        kindFilter: ShelfKindFilter = .all,
        appContext: AppContextKind = .generic,
        now: UInt64 = ShelfClock.now()
    ) -> [ShelfItem] {
        items
            .filter { ShelfLogic.matches($0, query: query, kindFilter: kindFilter) }
            .sorted { lhs, rhs in
                let left = score(item: lhs, query: query, appContext: appContext, now: now)
                let right = score(item: rhs, query: query, appContext: appContext, now: now)
                if left != right { return left > right }
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
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
        if title == q || content == q { return 1_000 }
        if title.hasPrefix(q) || content.hasPrefix(q) { return 850 }
        if title.contains(q) { return 700 }
        if content.contains(q) { return 650 }
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
}

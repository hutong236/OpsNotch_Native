import Foundation

public enum ShelfKind: String, Codable, CaseIterable, Sendable {
    case file
    case folder
    case url
    case application
    case action
    case text

    public init(legacyRawValue: String) {
        switch legacyRawValue {
        case "file": self = .file
        case "folder": self = .folder
        case "url": self = .url
        case "application": self = .application
        case "action": self = .action
        case "ip", "command", "text": self = .text
        default: self = .text
        }
    }
}

public enum StorageMode: String, Codable, CaseIterable, Sendable {
    case reference
    case copy
}

public enum SafeActionKind: String, Codable, CaseIterable, Sendable {
    case openPath = "open_path"
    case openURL = "open_url"
}

public enum DisplayTarget: String, Codable, CaseIterable, Sendable {
    case all
    case mouse
    case primary
    case current
}

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case zhCN = "zh-CN"
    case enUS = "en-US"
}

public struct ShelfSettings: Codable, Equatable, Sendable {
    public var tempTTLHours: UInt64
    public var addMode: StorageMode
    public var displayTarget: DisplayTarget
    public var language: AppLanguage

    public init(
        tempTTLHours: UInt64 = 24,
        addMode: StorageMode = .reference,
        displayTarget: DisplayTarget = .all,
        language: AppLanguage = .zhCN
    ) {
        self.tempTTLHours = tempTTLHours
        self.addMode = addMode
        self.displayTarget = displayTarget
        self.language = language
    }

    enum CodingKeys: String, CodingKey {
        case tempTTLHours = "temp_ttl_hours"
        case addMode = "add_mode"
        case displayTarget = "display_target"
        case language
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tempTTLHours = try container.decodeIfPresent(UInt64.self, forKey: .tempTTLHours) ?? 24
        addMode = try container.decodeIfPresent(StorageMode.self, forKey: .addMode) ?? .reference
        displayTarget = try container.decodeIfPresent(DisplayTarget.self, forKey: .displayTarget) ?? .all
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .zhCN
    }
}

public struct ShelfItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var kind: ShelfKind
    public var title: String
    public var content: String
    public var pinned: Bool
    public var createdAt: UInt64
    public var updatedAt: UInt64
    public var storageMode: StorageMode?
    public var actionKind: SafeActionKind?
    public var fileExtension: String?

    public init(
        id: UUID = UUID(),
        kind: ShelfKind,
        title: String,
        content: String,
        pinned: Bool = false,
        createdAt: UInt64 = ShelfClock.now(),
        updatedAt: UInt64 = ShelfClock.now(),
        storageMode: StorageMode? = nil,
        actionKind: SafeActionKind? = nil,
        fileExtension: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.content = content
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.storageMode = storageMode
        self.actionKind = actionKind
        self.fileExtension = fileExtension
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, title, content, pinned
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case storageMode = "storage_mode"
        case actionKind = "action_kind"
        case fileExtension = "extension"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let uuid = try? container.decode(UUID.self, forKey: .id) {
            id = uuid
        } else if let raw = try? container.decode(String.self, forKey: .id), let uuid = UUID(uuidString: raw) {
            id = uuid
        } else {
            id = UUID()
        }

        let rawKind = (try? container.decode(String.self, forKey: .kind)) ?? "text"
        kind = ShelfKind(legacyRawValue: rawKind)
        title = (try? container.decode(String.self, forKey: .title)) ?? "Untitled"
        content = (try? container.decode(String.self, forKey: .content)) ?? ""
        pinned = (try? container.decode(Bool.self, forKey: .pinned)) ?? false
        createdAt = Self.decodeTimestamp(container, key: .createdAt) ?? ShelfClock.now()
        updatedAt = Self.decodeTimestamp(container, key: .updatedAt) ?? createdAt
        storageMode = try? container.decode(StorageMode.self, forKey: .storageMode)
        actionKind = try? container.decode(SafeActionKind.self, forKey: .actionKind)
        fileExtension = try? container.decode(String.self, forKey: .fileExtension)
    }

    private static func decodeTimestamp(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> UInt64? {
        if let value = try? container.decode(UInt64.self, forKey: key) { return value }
        if let value = try? container.decode(Int64.self, forKey: key), value >= 0 { return UInt64(value) }
        if let value = try? container.decode(Double.self, forKey: key), value >= 0 { return UInt64(value) }
        return nil
    }
}

public struct ShelfStore: Codable, Equatable, Sendable {
    public static let currentVersion = 20

    public var version: Int
    public var items: [ShelfItem]
    public var settings: ShelfSettings

    public init(version: Int = currentVersion, items: [ShelfItem] = [], settings: ShelfSettings = .init()) {
        self.version = version
        self.items = items
        self.settings = settings
    }

    enum CodingKeys: String, CodingKey { case version, items, settings }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? container.decode(Int.self, forKey: .version)) ?? 1
        items = (try? container.decode([ShelfItem].self, forKey: .items)) ?? []
        settings = (try? container.decode(ShelfSettings.self, forKey: .settings)) ?? .init()
    }
}

public enum ShelfClock {
    public static func now() -> UInt64 {
        UInt64(Date().timeIntervalSince1970)
    }
}

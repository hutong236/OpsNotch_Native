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

/// 用户自定义全局呼出热键。keyCode 为虚拟键码,carbonModifiers 为 Carbon 修饰键位;
/// 与注册后端无关,便于将来替换热键实现而不改持久化格式。
public struct HotkeyShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }
}

/// Finder 快速路径。最多前 9 项可通过数字键 1...9 一步打开。
public struct FinderQuickPath: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var label: String
    public var path: String

    public init(id: UUID = UUID(), label: String, path: String) {
        self.id = id
        self.label = label
        self.path = path
    }

    enum CodingKeys: String, CodingKey { case id, label, path }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        label = (try? container.decode(String.self, forKey: .label)) ?? "Folder"
        path = (try? container.decode(String.self, forKey: .path)) ?? "~"
    }
}

public struct ShelfSettings: Codable, Equatable, Sendable {
    public var tempTTLHours: UInt64
    public var addMode: StorageMode
    public var displayTarget: DisplayTarget
    public var language: AppLanguage
    public var hotkey: HotkeyShortcut?

    /// 早期 Finder Spotlight 方案字段，保留用于配置向前兼容；快捷路径模式不再依赖它。
    public var finderRevealAppName: String
    /// Finder 快速路径启动器的全局快捷键。
    public var finderRevealHotkey: HotkeyShortcut?
    /// 启动器初始选中的默认目录；直接回车即打开。
    public var finderDefaultPath: String
    /// 用户收藏目录；前 9 项分别绑定数字键 1...9。
    public var finderQuickPaths: [FinderQuickPath]

    public init(
        tempTTLHours: UInt64 = 24,
        addMode: StorageMode = .reference,
        displayTarget: DisplayTarget = .all,
        language: AppLanguage = .zhCN,
        hotkey: HotkeyShortcut? = nil,
        finderRevealAppName: String = "gf.app",
        finderRevealHotkey: HotkeyShortcut? = nil,
        finderDefaultPath: String = "~",
        finderQuickPaths: [FinderQuickPath] = []
    ) {
        self.tempTTLHours = tempTTLHours
        self.addMode = addMode
        self.displayTarget = displayTarget
        self.language = language
        self.hotkey = hotkey
        self.finderRevealAppName = finderRevealAppName
        self.finderRevealHotkey = finderRevealHotkey
        self.finderDefaultPath = finderDefaultPath
        self.finderQuickPaths = Array(finderQuickPaths.prefix(9))
    }

    enum CodingKeys: String, CodingKey {
        case tempTTLHours = "temp_ttl_hours"
        case addMode = "add_mode"
        case displayTarget = "display_target"
        case language
        case hotkey
        case finderRevealAppName = "finder_reveal_app_name"
        case finderRevealHotkey = "finder_reveal_hotkey"
        case finderDefaultPath = "finder_default_path"
        case finderQuickPaths = "finder_quick_paths"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tempTTLHours = try container.decodeIfPresent(UInt64.self, forKey: .tempTTLHours) ?? 24
        addMode = try container.decodeIfPresent(StorageMode.self, forKey: .addMode) ?? .reference
        displayTarget = try container.decodeIfPresent(DisplayTarget.self, forKey: .displayTarget) ?? .all
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .zhCN
        hotkey = try container.decodeIfPresent(HotkeyShortcut.self, forKey: .hotkey)
        finderRevealAppName = try container.decodeIfPresent(String.self, forKey: .finderRevealAppName) ?? "gf.app"
        finderRevealHotkey = try container.decodeIfPresent(HotkeyShortcut.self, forKey: .finderRevealHotkey)
        finderDefaultPath = try container.decodeIfPresent(String.self, forKey: .finderDefaultPath) ?? "~"
        finderQuickPaths = Array((try container.decodeIfPresent([FinderQuickPath].self, forKey: .finderQuickPaths) ?? []).prefix(9))
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
    public static let currentVersion = 21

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

#if os(macOS)
import Foundation
import OpsNotchCore

/// Build once per snapshot/language change, then share the value across row and inspector.
/// Image providers may cache the descriptors; adapting never probes paths or decodes images.
@MainActor
enum ShelfPresentationAdapter {
    typealias Item = ShelfPresentationItem

    static func adapt(_ entries: [QuickShelfEntry], language: AppLanguage, workingSetItemIDs: Set<UUID> = []) -> [Item] {
        let items = entries.map { adapt($0, language: language, workingSetItemIDs: workingSetItemIDs) }
        assert(Set(items.map(\.id)).count == items.count, "Presentation snapshot IDs must be unique")
        return items
    }

    static func adapt(_ entry: QuickShelfEntry, language: AppLanguage,
                      semanticKind: SemanticKind? = nil, workingSetItemIDs: Set<UUID> = []) -> Item {
        assert(!entry.id.isEmpty, "Presentation identity must not be empty")
        switch entry {
        case .desktop(_, let title, let subtitle, let command):
            let action: Item.Action
            switch command {
            case .list:
                action = .init(intent: .desktop(command), title: L10n.text("presentationShowDesktops", language), symbolName: "rectangle.3.group")
            case .switchTo(let index):
                assert(index > 0, "Desktop index must be positive")
                action = .init(intent: .desktop(command), title: L10n.text("presentationSwitchDesktop", language), symbolName: "rectangle.3.group")
            }
            return make(entry, icon: .symbol("rectangle.3.group"), title: title, subtitle: subtitle,
                        primary: action, preview: .unavailable, inspector: .desktop(command))
        case .finder(_, let title, let path, let quickPathID):
            return pathItem(entry, title: title, path: path, isDirectory: true,
                            primary: .init(intent: .openFinder(path: path, quickPathID: quickPathID),
                                           title: L10n.text("openFolder", language), symbolName: "folder"), language: language)
        case .local(_, let title, let path, let isDirectory):
            return pathItem(entry, title: title, path: path, isDirectory: isDirectory,
                            primary: .init(intent: .openLocal(path: path, isDirectory: isDirectory), title: L10n.text(isDirectory ? "openFolder" : "copy", language), symbolName: isDirectory ? "folder" : "doc.on.doc"), language: language)
        case .shelf(let item):
            return adaptShelf(entry, item: item, kind: semanticKind ?? ShelfSemantic.kind(for: item), language: language, inWorkingSet: workingSetItemIDs.contains(item.id))
        }
    }

    static func adapt(_ item: ShelfItem, semanticKind: SemanticKind? = nil, language: AppLanguage, workingSetItemIDs: Set<UUID> = []) -> Item {
        adapt(.shelf(item), language: language, semanticKind: semanticKind, workingSetItemIDs: workingSetItemIDs)
    }

    private static func pathItem(_ entry: QuickShelfEntry, title: String, path: String, isDirectory: Bool,
                                 primary: Item.Action, language: AppLanguage) -> Item {
        let image = !isDirectory && ItemPreviewKind.isImagePath(path)
        let preview: Item.Preview = isDirectory ? .unavailable : (image ? .imageFile(path: path) : .quickLook(path: path))
        var actions: [Item.Action] = [
            .init(intent: .copyPath(path), title: L10n.text("copyPath", language), symbolName: "doc.on.doc"),
            .init(intent: .revealPath(path), title: L10n.text("reveal", language), symbolName: "folder")
        ]
        if preview != .unavailable { actions.append(.init(intent: .quickLook(path: path), title: L10n.text("quickLook", language), symbolName: "eye")) }
        return make(entry, icon: .file(path: path, fallbackSymbol: isDirectory ? "folder" : "doc"),
                    thumbnail: image ? .imageFile(path: path) : nil, title: title, subtitle: path,
                    kind: isDirectory ? .folder : .file, primary: primary, secondary: actions,
                    preview: preview, quickLookPath: isDirectory ? nil : path, inspector: .path(path))
    }

    private static func adaptShelf(_ entry: QuickShelfEntry, item: ShelfItem, kind: SemanticKind, language: AppLanguage, inWorkingSet: Bool) -> Item {
        let icon: Item.Icon
        let thumbnail: Item.Thumbnail?
        let preview: Item.Preview
        let subtitle: String
        let copies: Bool
        var secondary: [Item.Action] = [
            .init(intent: .setPinned(itemID: item.id, pinned: !item.pinned), title: L10n.text(item.pinned ? "unpin" : "pin", language), symbolName: item.pinned ? "pin.slash" : "pin")
        ]
        switch item.kind {
        case .file, .folder, .application:
            let image = item.kind == .file && ItemPreviewKind.isPreviewable(item)
            icon = .file(path: item.content, fallbackSymbol: symbol(kind))
            thumbnail = image ? .imageFile(path: item.content) : nil
            preview = item.kind == .file ? (image ? .imageFile(path: item.content) : .quickLook(path: item.content)) : .unavailable
            subtitle = item.clipboardImage ? L10n.text("presentationClipboardImage", language) : item.content
            copies = item.kind == .file && item.clipboardImage
            secondary.append(.init(intent: .revealPath(item.content), title: L10n.text("reveal", language), symbolName: "folder"))
        case .text:
            icon = .symbol(symbol(kind)); thumbnail = nil
            preview = item.content.isEmpty ? .unavailable : .text(item.content)
            subtitle = item.content.replacingOccurrences(of: "\n", with: " ")
            copies = true
        case .url:
            icon = .symbol(symbol(kind)); thumbnail = nil; preview = .unavailable
            subtitle = item.content; copies = false
        case .action:
            icon = .symbol(symbol(kind)); thumbnail = nil; preview = .unavailable; copies = false
            switch item.actionKind {
            case .openPath: subtitle = L10n.text("presentationLocalPath", language)
            case .openURL: subtitle = "HTTP/HTTPS"
            case nil: subtitle = L10n.text("presentationSafeAction", language)
            }
        }
        if item.kind == .text || item.kind == .url || item.clipboardImage {
            secondary.append(.init(intent: .copyShelfItem(item.id), title: L10n.text("copy", language), symbolName: "doc.on.doc"))
        }
        if item.kind == .file || item.kind == .folder {
            secondary.append(.init(intent: .quickLook(path: item.content), title: L10n.text("quickLook", language), symbolName: "eye"))
        }
        if ItemPreviewKind.isPreviewable(item) {
            secondary.append(.init(intent: .floatingPreview(itemID: item.id), title: L10n.text("presentationFloatingPreview", language), symbolName: "arrow.up.left.and.arrow.down.right"))
        }
        secondary.append(.init(intent: .setWorkingSet(itemID: item.id, included: !inWorkingSet), title: L10n.text(inWorkingSet ? "workingSetRemove" : "workingSetAdd", language), symbolName: inWorkingSet ? "tray.full.fill" : "tray.full"))
        secondary.append(.init(intent: .editShelfItem(item.id), title: L10n.text("edit", language), symbolName: "pencil"))
        secondary.append(.init(intent: .removeShelfItem(item.id), title: L10n.text("remove", language), symbolName: "trash"))
        var metadata: [String] = []
        let source = item.sourceAppName?.trimmingCharacters(in: .whitespacesAndNewlines)
        metadata.append(source.flatMap { $0.isEmpty ? nil : $0 } ?? L10n.text(item.clipboardImage ? "shelfKindImage" : "shelfKind_\(item.kind.rawValue)", language))
        metadata.append(ShelfRelativeTime.text(updatedAt: item.updatedAt, now: ShelfClock.now(), language: language))
        if let ext = item.fileExtension, !ext.isEmpty { metadata.append(ext.uppercased()) }
        if item.pinned { metadata.append(L10n.text("pinned", language)) }
        return make(entry, icon: icon, thumbnail: thumbnail, title: item.title, subtitle: subtitle,
                    metadata: metadata, kind: kind, badge: badge(kind, shelfKind: item.kind, language: language),
                    primary: .init(intent: .useShelfItem(item.id), title: copies ? L10n.text("copy", language) : L10n.text("presentationOpen", language), symbolName: copies ? "doc.on.doc" : "arrow.up.forward"),
                    secondary: secondary, preview: preview, quickLookPath: (item.kind == .file || item.kind == .folder) ? item.content : nil, inspector: .shelfItem(item.id))
    }

    private static func make(_ entry: QuickShelfEntry, icon: Item.Icon, thumbnail: Item.Thumbnail? = nil,
                             title: String, subtitle: String, metadata: [String] = [], kind: SemanticKind? = nil,
                             badge: String? = nil, primary: Item.Action, secondary: [Item.Action] = [],
                             preview: Item.Preview, quickLookPath: String? = nil, inspector: Item.Inspector) -> Item {
        let label = ([title, subtitle] + metadata + [badge].compactMap { $0 }).filter { !$0.isEmpty }.joined(separator: ", ")
        return Item(id: entry.id, icon: icon, thumbnail: thumbnail, title: title, subtitle: subtitle,
                    metadata: metadata, semanticKind: kind, badge: badge, primaryAction: primary,
                    secondaryActions: secondary, preview: preview, quickLookPath: quickLookPath, inspector: inspector,
                    accessibilityLabel: label, accessibilityHint: primary.title)
    }

    private static func symbol(_ kind: SemanticKind) -> String {
        switch kind {
        case .file: return "doc"
        case .folder: return "folder"
        case .application: return "app"
        case .url: return "globe"
        case .ipv4: return "network"
        case .ssh: return "terminal"
        case .command: return "chevron.left.forwardslash.chevron.right"
        case .path: return "point.topleft.down.curvedto.point.bottomright.up"
        case .text: return "doc.text"
        case .action: return "play.circle"
        }
    }

    private static func badge(_ kind: SemanticKind, shelfKind: ShelfKind, language: AppLanguage) -> String? {
        switch kind {
        case .ipv4: return L10n.text("semanticIP", language)
        case .ssh: return L10n.text("semanticSSH", language)
        case .command: return L10n.text("semanticCommand", language)
        case .path: return L10n.text("semanticPath", language)
        case .url: return shelfKind == .text ? L10n.text("semanticURL", language) : nil
        case .file, .folder, .application, .text, .action: return nil
        }
    }

}
/// Evaluated when presentation data changes, with no timer or work in row rendering.
@MainActor
enum ShelfRelativeTime {
    static func text(updatedAt: UInt64, now: UInt64, language: AppLanguage) -> String {
        let elapsed = now >= updatedAt ? min(now - updatedAt, UInt64(Int.max)) : 0
        if elapsed < 60 { return L10n.text("shelfTimeNow", language) }
        let key: String
        let count: Int
        if elapsed < 3600 { key = "shelfTimeMinutes"; count = Int(elapsed / 60) }
        else if elapsed < 86_400 { key = "shelfTimeHours"; count = Int(elapsed / 3600) }
        else { key = "shelfTimeDays"; count = Int(elapsed / 86_400) }
        return String(format: L10n.text(key, language), count)
    }
}
#endif

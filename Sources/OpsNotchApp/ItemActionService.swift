#if os(macOS)
import AppKit
import Foundation
import OpsNotchCore

@MainActor
enum ItemActionService {
    static func performDefault(_ item: ShelfItem, clipboard: ClipboardManager, model: AppModel) {
        var succeeded = false
        switch item.kind {
        case .text:
            clipboard.copyFromApp(item.content)
            model.showToast(L10n.text("copied", model.language))
            succeeded = true
        case .url:
            if let url = URL(string: item.content) {
                succeeded = NSWorkspace.shared.open(url)
            }
        case .file, .folder:
            succeeded = NSWorkspace.shared.open(URL(fileURLWithPath: item.content))
        case .application:
            succeeded = NSWorkspace.shared.open(URL(fileURLWithPath: item.content))
        case .action:
            guard let kind = item.actionKind, SafeActionValidator.validate(kind: kind, content: item.content) else {
                model.showToast(L10n.text("invalidAction", model.language)); return
            }
            switch kind {
            case .openPath:
                succeeded = NSWorkspace.shared.open(URL(fileURLWithPath: item.content))
            case .openURL:
                if let url = URL(string: item.content) {
                    succeeded = NSWorkspace.shared.open(url)
                }
            }
        }
        if succeeded { model.recordUse(item.id) }
    }

    static func reveal(_ item: ShelfItem) {
        guard [.file, .folder, .application].contains(item.kind) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.content)])
    }

    static func icon(for item: ShelfItem) -> NSImage? {
        switch item.kind {
        case .file, .folder, .application:
            return NSWorkspace.shared.icon(forFile: item.content)
        default:
            return nil
        }
    }
}
#endif

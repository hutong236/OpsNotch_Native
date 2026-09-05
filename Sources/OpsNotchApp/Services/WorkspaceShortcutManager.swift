import AppKit
import Carbon

/// Registers application level shortcuts for workspace switching.
///
/// This layer only manages shortcut intent. Actual Space switching is delegated
/// to WorkspaceService to keep macOS event handling isolated.
final class WorkspaceShortcutManager {
    static let shared = WorkspaceShortcutManager()

    private var handlers: [UInt32: () -> Void] = [:]

    private init() {}

    func registerDefaultShortcuts() {
        // Reserved for Carbon global hotkey registration.
        // The first version keeps registration isolated so permissions and
        // lifecycle handling can be added without changing WorkspaceService.
        handlers.removeAll()

        handlers[1] = {
            WorkspaceService.shared.switchNextSpace()
        }

        handlers[2] = {
            WorkspaceService.shared.switchPreviousSpace()
        }
    }

    func trigger(id: UInt32) {
        handlers[id]?()
    }

    func removeAll() {
        handlers.removeAll()
    }
}

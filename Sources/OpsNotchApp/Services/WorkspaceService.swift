import AppKit
import CoreGraphics

/// Lightweight macOS Space switching service.
///
/// This service intentionally does not query Mission Control state or use
/// private CGS/SkyLight APIs. It only emits the same keyboard shortcut a user
/// would press manually.
final class WorkspaceService {
    static let shared = WorkspaceService()

    private init() {}

    func switchNextSpace() {
        sendControlArrow(.right)
    }

    func switchPreviousSpace() {
        sendControlArrow(.left)
    }

    func execute(steps: Int) {
        guard steps != 0 else { return }

        let direction: CGKeyCode = steps > 0 ? 0x7C : 0x7B // right / left arrows
        for _ in 0..<abs(steps) {
            sendControlArrow(direction == 0x7C ? .right : .left)
        }
    }

    private enum Arrow {
        case left
        case right

        var keyCode: CGKeyCode {
            switch self {
            case .left: return 0x7B
            case .right: return 0x7C
            }
        }
    }

    private func sendControlArrow(_ arrow: Arrow) {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: arrow.keyCode,
            keyDown: true
        )
        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: arrow.keyCode,
            keyDown: false
        )

        keyDown?.flags = .maskControl
        keyUp?.flags = .maskControl

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

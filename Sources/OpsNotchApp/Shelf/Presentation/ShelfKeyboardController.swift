#if os(macOS)
import AppKit

@MainActor
final class ShelfKeyboardController {
    enum Command: Equatable {
        case moveLeft
        case moveRight
        case moveUp
        case moveDown
        case confirm
        case escape
        case focusSearch
        case togglePin
        case remove
        case preview
    }

    private let model: AppModel
    private let clipboard: ClipboardManager

    init(model: AppModel, clipboard: ClipboardManager) {
        self.model = model
        self.clipboard = clipboard
    }

    static func resolve(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        firstResponderIsTextView: Bool
    ) -> Command? {
        let normalized = modifiers
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .function, .numericPad])

        switch keyCode {
        case 123: return .moveLeft
        case 124: return .moveRight
        case 125: return .moveDown
        case 126: return .moveUp
        case 36, 76: return .confirm
        case 53: return .escape
        case 48:
            guard normalized.subtracting(.shift).isEmpty else { return nil }
            return .focusSearch
        case 35:
            return normalized == .command ? .togglePin : nil
        case 2:
            return normalized == .command ? .remove : nil
        case 49:
            guard normalized.isEmpty, !firstResponderIsTextView else { return nil }
            return .preview
        default:
            return nil
        }
    }

    func handle(_ event: NSEvent, firstResponder: NSResponder?) -> Bool {
        guard let command = Self.resolve(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags,
            firstResponderIsTextView: firstResponder is NSTextView
        ) else { return false }

        switch command {
        case .moveLeft:
            model.moveHorizontalHighlight(.left)
            return true
        case .moveRight:
            model.moveHorizontalHighlight(.right)
            return true
        case .moveUp:
            model.moveHighlight(-1)
            return true
        case .moveDown:
            model.moveHighlight(1)
            return true
        case .confirm:
            model.confirmHighlight(using: clipboard)
            return true
        case .escape:
            model.escapeShelf()
            return true
        case .focusSearch:
            if !(firstResponder is NSTextView) {
                model.focusRequestToken = UUID()
            }
            return true
        case .togglePin:
            return model.togglePinHighlighted()
        case .remove:
            return model.removeHighlighted()
        case .preview:
            return model.quickLookHighlighted()
        }
    }
}
#endif

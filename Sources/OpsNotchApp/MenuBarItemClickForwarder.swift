#if os(macOS)
import AppKit
import ApplicationServices

enum MenuBarPanelInteraction: Equatable {
    case primary
    case secondary
}

/// Delivers a mouse pair to a specific menu-extra window, including an offscreen one.
/// Posting to the owner PID avoids global hit testing against the spacer or the panel.
enum MenuBarItemClickForwarder {
    struct Target: Equatable {
        let pid: pid_t
        let windowID: CGWindowID
        let frame: CGRect
    }

    private static let messagingTimeout: Float = 0.18
    // AppKit's destination window field. Keep this compatibility detail at the native edge;
    // the macOS probe verifies NSEvent decoding and delivery using the production event pair.
    private static let destinationWindow = CGEventField(rawValue: 0x33)!

    /// Read current AX geometry, never the scan's cached position. Window metadata is available
    /// without capturing screen pixels. Ambiguous matches fail instead of clicking a sibling.
    static func resolve(_ element: AXUIElement) -> Target? {
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid > 0,
              let frame = frame(of: element),
              let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        let matches = windows.compactMap(target(from:)).filter {
            $0.pid == pid && sameFrame($0.frame, frame)
        }
        return matches.count == 1 ? matches.first : nil
    }

    /// Revalidate identity immediately before sending. A moved window keeps its identity and
    /// uses its new coordinates; a terminated/replaced owner cannot receive a stale click.
    static func currentTarget(_ target: Target) -> Target? {
        guard let windows = CGWindowListCopyWindowInfo(.optionIncludingWindow, target.windowID)
                as? [[String: Any]],
              let current = windows.compactMap(Self.target(from:)).first(where: {
                  $0.windowID == target.windowID && $0.pid == target.pid
              }) else { return nil }
        return current
    }

    static func makeEvents(for target: Target, interaction: MenuBarPanelInteraction) -> (down: CGEvent, up: CGEvent)? {
        guard target.pid > 0, target.windowID != kCGNullWindowID, validFrame(target.frame),
              let source = CGEventSource(stateID: .privateState) else { return nil }
        let secondary = interaction == .secondary
        let point = CGPoint(x: target.frame.midX, y: target.frame.midY)
        let button: CGMouseButton = secondary ? .right : .left
        guard let down = CGEvent(mouseEventSource: source,
                                 mouseType: secondary ? .rightMouseDown : .leftMouseDown,
                                 mouseCursorPosition: point, mouseButton: button),
              let up = CGEvent(mouseEventSource: source,
                               mouseType: secondary ? .rightMouseUp : .leftMouseUp,
                               mouseCursorPosition: point, mouseButton: button) else { return nil }
        for event in [down, up] {
            // Control-click was already mapped to secondary. Command must never turn an
            // activation into a status-item drag, so do not inherit the user's modifier flags.
            event.flags = []
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(target.pid))
            event.setIntegerValueField(destinationWindow, value: Int64(target.windowID))
            event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(target.windowID))
            event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent,
                                       value: Int64(target.windowID))
        }
        return (down, up)
    }

    /// True means the pair was submitted, not that a third-party app showed UI.
    /// Never retry AXPress after posting: that can toggle a just-opened menu closed again.
    static func post(to target: Target, interaction: MenuBarPanelInteraction) -> Bool {
        guard let current = currentTarget(target),
              let events = makeEvents(for: current, interaction: interaction) else { return false }
        events.down.postToPid(current.pid)
        events.up.postToPid(current.pid)
        return true
    }

    private static func target(from window: [String: Any]) -> Target? {
        guard let pid = window[kCGWindowOwnerPID as String] as? Int32, pid > 0,
              let id = window[kCGWindowNumber as String] as? UInt32, id != kCGNullWindowID,
              let layer = window[kCGWindowLayer as String] as? Int,
              layer == Int(CGWindowLevelForKey(.statusWindow)),
              let bounds = window[kCGWindowBounds as String] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary), validFrame(frame) else { return nil }
        return Target(pid: pid, windowID: id, frame: frame)
    }

    private static func sameFrame(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) < 1 && abs(lhs.minY - rhs.minY) < 1
            && abs(lhs.width - rhs.width) < 1 && abs(lhs.height - rhs.height) < 1
    }

    private static func validFrame(_ frame: CGRect) -> Bool {
        [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite)
            && frame.width > 0 && frame.height > 0
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size,
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        let positionValue = position as! AXValue
        let sizeValue = size as! AXValue
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetType(positionValue) == .cgPoint, AXValueGetType(sizeValue) == .cgSize,
              AXValueGetValue(positionValue, .cgPoint, &point),
              AXValueGetValue(sizeValue, .cgSize, &dimensions) else { return nil }
        let frame = CGRect(origin: point, size: dimensions)
        return validFrame(frame) ? frame : nil
    }
}
#endif

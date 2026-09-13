#if os(macOS)
import AppKit
import ApplicationServices
import Darwin
import OSLog

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
        /// Coordinates within the owning window, with a top-left origin (Quartz).
        let localPoint: CGPoint?

        init(pid: pid_t, windowID: CGWindowID, frame: CGRect, localPoint: CGPoint? = nil) {
            self.pid = pid
            self.windowID = windowID
            self.frame = frame
            self.localPoint = localPoint
        }

        var pointInWindow: CGPoint {
            localPoint ?? CGPoint(x: frame.width / 2, y: frame.height / 2)
        }
    }

    struct Window {
        let pid: pid_t
        let id: CGWindowID
        let frame: CGRect
        let layer: Int
    }

    struct Resolution {
        let target: Target?
        let diagnostic: String
    }

    private static let messagingTimeout: Float = 0.18
    private static let log = Logger(subsystem: "lab.hutong.opsnotch", category: "menu-bar-click")
    private typealias AXWindowID = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private static let axWindowID: AXWindowID? = {
        guard let image = dlopen(nil, RTLD_LAZY),
              let symbol = dlsym(image, "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(symbol, to: AXWindowID.self)
    }()
    // AppKit's destination window field. Keep this compatibility detail at the native edge;
    // the macOS probe verifies NSEvent decoding and delivery using the production event pair.
    private static let destinationWindow = CGEventField(rawValue: 0x33)!
    private typealias SetWindowLocation = @convention(c) (CGEvent, CGPoint) -> Void
    private static let setWindowLocation: SetWindowLocation? = {
        // Retain the framework for the process lifetime, as the stored function pointer uses it.
        guard let image = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let symbol = dlsym(image, "CGEventSetWindowLocation") else { return nil }
        return unsafeBitCast(symbol, to: SetWindowLocation.self)
    }()

    /// Prefer the AX owning window, then uniquely match a containing status window. An AX button
    /// can be inset inside that window: equality between their rectangles is not required.
    static func resolve(_ element: AXUIElement) -> Resolution {
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid > 0 else {
            return resolution(nil, detail: "stage=ax-pid")
        }
        guard let frame = frame(of: element) else {
            return resolution(nil, detail: "stage=ax-frame pid=\(pid)")
        }
        let identifier = owningWindowID(of: element)
        // A targeted description query can find a hidden window that a broad list omitted.
        if let identifier, let window = readWindow(identifier),
           let target = match(pid: pid, elementFrame: frame, windowID: identifier, windows: [window]) {
            return resolution(target, detail: "stage=ax-window pid=\(pid) window=\(identifier) ax=\(frame) native=\(window.frame) layer=\(window.layer)")
        }
        let info = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let windows = info.compactMap(window(from:)).filter { $0.pid == pid }
        let target = match(pid: pid, elementFrame: frame, windowID: identifier, windows: windows)
        let candidates = windows.prefix(8).map { "\($0.id)/layer=\($0.layer)/\($0.frame)" }.joined(separator: "; ")
        return resolution(target, detail: "stage=window-match pid=\(pid) axWindow=\(identifier.map(String.init) ?? "none") ax=\(frame) candidates=[\(candidates)]")
    }

    /// Shared by the resolver and regression probe. An authoritative AX window ID must not
    /// silently fall back to another window when it disappears or has a different owner.
    static func match(pid: pid_t, elementFrame: CGRect, windowID: CGWindowID?, windows: [Window]) -> Target? {
        guard pid > 0, validFrame(elementFrame) else { return nil }
        let candidates = windows.filter { window in
            guard window.pid == pid, window.id != kCGNullWindowID, validFrame(window.frame) else { return false }
            if let windowID { return window.id == windowID }
            return window.layer == Int(CGWindowLevelForKey(.statusWindow))
                && contains(elementFrame, in: window.frame)
        }
        guard candidates.count == 1, let window = candidates.first,
              contains(elementFrame, in: window.frame) else { return nil }
        let point = CGPoint(x: elementFrame.midX - window.frame.minX,
                            y: elementFrame.midY - window.frame.minY)
        guard CGRect(origin: .zero, size: window.frame.size).contains(point) else { return nil }
        return Target(pid: pid, windowID: window.id, frame: window.frame, localPoint: point)
    }

    /// Revalidate identity immediately before sending. A moved window keeps its identity and
    /// uses its new coordinates; a terminated/replaced owner cannot receive a stale click.
    static func currentTarget(_ target: Target) -> Target? {
        guard let window = readWindow(target.windowID), window.pid == target.pid else { return nil }
        // A translated window preserves the point. If it resized, discard an old subview point
        // rather than potentially hitting a different control; the next click resolves fresh AX.
        if target.localPoint != nil, window.frame.size != target.frame.size { return nil }
        return Target(pid: window.pid, windowID: window.id, frame: window.frame, localPoint: target.localPoint)
    }

    static func makeEvents(for target: Target, interaction: MenuBarPanelInteraction) -> (down: CGEvent, up: CGEvent)? {
        guard target.pid > 0, target.windowID != kCGNullWindowID, validFrame(target.frame),
              let setWindowLocation else { return nil }
        let secondary = interaction == .secondary
        let local = target.pointInWindow
        guard CGRect(origin: .zero, size: target.frame.size).contains(local) else { return nil }
        let point = CGPoint(x: target.frame.minX + local.x, y: target.frame.minY + local.y)
        // PID delivery bypasses WindowServer's global-to-window coordinate conversion.
        // Construct the native event with local coordinates first, then supply its screen point.
        // A raw CGEvent with only a screen point can reach the window but miss its button.
        func makeEvent(_ type: NSEvent.EventType) -> CGEvent? {
            NSEvent.mouseEvent(with: type,
                               location: NSPoint(x: local.x, y: target.frame.height - local.y),
                               modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                               windowNumber: Int(target.windowID), context: nil,
                               eventNumber: 0, clickCount: 1, pressure: 0)?.cgEvent
        }
        guard let down = makeEvent(secondary ? .rightMouseDown : .leftMouseDown),
              let up = makeEvent(secondary ? .rightMouseUp : .leftMouseUp) else { return nil }
        for event in [down, up] {
            event.location = point
            // Control-click was already mapped to secondary. Command must never turn an
            // activation into a status-item drag, so do not inherit the user's modifier flags.
            event.flags = []
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(target.pid))
            event.setIntegerValueField(destinationWindow, value: Int64(target.windowID))
            event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(target.windowID))
            event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent,
                                       value: Int64(target.windowID))
            // NSEvent cannot resolve another process's NSWindow during the CGEvent conversion.
            // Explicit local coordinates are required for foreign destinations as well.
            setWindowLocation(event, local)
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

    private static func window(from window: [String: Any]) -> Window? {
        guard let pid = window[kCGWindowOwnerPID as String] as? Int32, pid > 0,
              let id = window[kCGWindowNumber as String] as? UInt32, id != kCGNullWindowID,
              let layer = window[kCGWindowLayer as String] as? Int,
              let bounds = window[kCGWindowBounds as String] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary), validFrame(frame) else { return nil }
        return Window(pid: pid, id: id, frame: frame, layer: layer)
    }

    private static func contains(_ element: CGRect, in window: CGRect) -> Bool {
        // Accommodate fractional-point rounding, including Retina displays, without matching
        // adjacent icons or choosing an arbitrary closest window.
        window.insetBy(dx: -1, dy: -1).contains(element)
    }

    private static func readWindow(_ identifier: CGWindowID) -> Window? {
        // This API takes a CFArray of raw window IDs, not CFNumbers/NSNumbers.
        var value = UnsafeRawPointer(bitPattern: UInt(identifier))
        guard let ids = CFArrayCreate(kCFAllocatorDefault, &value, 1, nil),
              let info = CGWindowListCreateDescriptionFromArray(ids) as? [[String: Any]] else { return nil }
        return info.compactMap(window(from:)).first { $0.id == identifier }
    }

    private static func owningWindowID(of element: AXUIElement) -> CGWindowID? {
        guard let axWindowID else { return nil }
        var identifier: CGWindowID = 0
        if axWindowID(element, &identifier) == .success, identifier != 0 { return identifier }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let window = value as! AXUIElement
        AXUIElementSetMessagingTimeout(window, messagingTimeout)
        return axWindowID(window, &identifier) == .success && identifier != 0 ? identifier : nil
    }

    private static func resolution(_ target: Target?, detail: String) -> Resolution {
        let message = "\(target == nil ? "failed" : "resolved") \(detail)"
        if target == nil { log.error("\(message, privacy: .public)") }
        else { log.debug("\(message, privacy: .public)") }
        return Resolution(target: target, diagnostic: message)
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

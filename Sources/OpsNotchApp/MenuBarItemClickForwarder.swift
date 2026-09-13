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
    enum WindowSource: String {
        case publicDescription
        case windowServer
    }

    struct Target: Equatable {
        /// PID that owns the native destination window. A proxied AX menu item can have a
        /// different AX PID; events must always be posted to this native window owner.
        let pid: pid_t
        let windowID: CGWindowID
        let frame: CGRect
        /// Coordinates within the owning window, with a top-left origin (Quartz).
        let localPoint: CGPoint?
        let source: WindowSource

        init(pid: pid_t, windowID: CGWindowID, frame: CGRect, localPoint: CGPoint? = nil,
             source: WindowSource = .publicDescription) {
            self.pid = pid
            self.windowID = windowID
            self.frame = frame
            self.localPoint = localPoint
            self.source = source
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
        let source: WindowSource

        init(pid: pid_t, id: CGWindowID, frame: CGRect, layer: Int,
             source: WindowSource = .publicDescription) {
            self.pid = pid
            self.id = id
            self.frame = frame
            self.layer = layer
            self.source = source
        }
    }

    /// The regression probe can omit a status item from the public list while returning it
    /// from the real fallback path. This exercises lookup ordering, not just rectangle math.
    struct WindowQueries {
        let byID: (CGWindowID) -> Window?
        let publicWindows: () -> [Window]
        let menuBarWindows: () -> MenuBarWindowServer.Inventory

        static var live: WindowQueries {
            WindowQueries(byID: { MenuBarItemClickForwarder.readWindow($0) ?? MenuBarWindowServer.readWindow($0) },
                publicWindows: {
                    let info = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
                        as? [[String: Any]] ?? []
                    return info.compactMap(MenuBarItemClickForwarder.window(from:))
                }, menuBarWindows: { MenuBarWindowServer.menuBarWindows() })
        }
    }

    struct Resolution {
        let target: Target?
        let diagnostic: String
    }

    private static let messagingTimeout: Float = 0.18
    private static let statusWindowLayer = Int(CGWindowLevelForKey(.statusWindow))
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
        return resolve(pid: pid, elementFrame: frame, windowID: owningWindowID(of: element))
    }

    static func resolve(pid: pid_t, elementFrame frame: CGRect, windowID identifier: CGWindowID?,
                        queries: WindowQueries = .live) -> Resolution {
        guard pid > 0, validFrame(frame) else { return resolution(nil, detail: "stage=invalid-ax-data") }
        // A targeted description query can find a hidden window that a broad list omitted.
        if let identifier, let window = queries.byID(identifier),
           let target = match(pid: pid, elementFrame: frame, windowID: identifier, windows: [window]) {
            return resolution(target, detail: "stage=ax-window pid=\(pid) window=\(identifier) ax=\(frame) native=\(window.frame) source=\(window.source.rawValue)")
        }
        let windows = queries.publicWindows().filter { $0.pid == pid }
        if let target = match(pid: pid, elementFrame: frame, windowID: identifier, windows: windows) {
            return resolution(target, detail: "stage=public-window pid=\(pid) window=\(target.windowID) ax=\(frame) native=\(target.frame)")
        }
        // AX can expose an offscreen extra without AXWindow, while CG's generic list exposes
        // only unrelated app windows. Ask the menu-bar inventory instead of widening geometry.
        let inventory = queries.menuBarWindows()
        let menuWindows = inventory.windows.filter { $0.pid == pid }
        if let target = match(pid: pid, elementFrame: frame, windowID: identifier, windows: menuWindows) {
            return resolution(target, detail: "stage=server-window ax-pid=\(pid) window-pid=\(target.pid) window=\(target.windowID) ax=\(frame) native=\(target.frame)")
        }

        // macOS can expose the AX status item from one process while a different process owns
        // the native status-window that receives mouse events. Only use this fallback when AX
        // has no authoritative window ID, and only when exactly one foreign status-window
        // geometrically contains the AX item. Never choose a nearest/first foreign window.
        let proxyWindows: [Window]
        if identifier == nil {
            proxyWindows = inventory.windows.filter {
                $0.pid != pid && $0.id != kCGNullWindowID && validFrame($0.frame)
                    && $0.layer == statusWindowLayer && contains(frame, in: $0.frame)
            }
        } else {
            proxyWindows = []
        }
        if proxyWindows.count == 1, let proxy = proxyWindows.first,
           let target = target(for: proxy, elementFrame: frame) {
            return resolution(target, detail: "stage=server-proxy-window ax-pid=\(pid) window-pid=\(target.pid) window=\(target.windowID) ax=\(frame) native=\(target.frame)")
        }

        func describe(_ windows: [Window]) -> String {
            windows.sorted { lhs, rhs in
                let left = contains(frame, in: lhs.frame)
                let right = contains(frame, in: rhs.frame)
                return left == right ? lhs.id < rhs.id : left
            }.prefix(8).map { "\($0.id)/pid=\($0.pid)/layer=\($0.layer)/\($0.frame)" }.joined(separator: "; ")
        }
        // Include counts before truncation and geometrically relevant other owners. This makes
        // an empty roster, an owner mismatch, ambiguity, and unrelated windows distinguishable.
        let otherOwners = inventory.windows.filter { $0.pid != pid && contains(frame, in: $0.frame) }
        return resolution(nil, detail: "stage=server-window-match pid=\(pid) axWindow=\(identifier.map(String.init) ?? "none") ax=\(frame) \(inventory.diagnostic) public-count=\(windows.count) public=[\(describe(windows))] menu-owner-count=\(menuWindows.count) menu=[\(describe(menuWindows))] proxy-count=\(proxyWindows.count) proxy=[\(describe(proxyWindows))] other-owners=[\(describe(otherOwners))]")
    }

    /// Shared by the resolver and regression probe. An authoritative AX window ID must not
    /// silently fall back to another window when it disappears or has a different owner.
    static func match(pid: pid_t, elementFrame: CGRect, windowID: CGWindowID?, windows: [Window]) -> Target? {
        guard pid > 0, validFrame(elementFrame) else { return nil }
        let candidates = windows.filter { window in
            guard window.pid == pid, window.id != kCGNullWindowID, validFrame(window.frame) else { return false }
            if let windowID { return window.id == windowID }
            return window.layer == statusWindowLayer && contains(elementFrame, in: window.frame)
        }
        guard candidates.count == 1, let window = candidates.first else { return nil }
        return target(for: window, elementFrame: elementFrame)
    }

    /// Revalidate identity immediately before sending. A moved window keeps its identity and
    /// uses its new coordinates; a terminated/replaced owner cannot receive a stale click.
    static func currentTarget(_ target: Target) -> Target? {
        let window = target.source == .windowServer
            ? MenuBarWindowServer.readWindow(target.windowID) : readWindow(target.windowID)
        guard let window, window.pid == target.pid else { return nil }
        // A translated window preserves the point. If it resized, discard an old subview point
        // rather than potentially hitting a different control; the next click resolves fresh AX.
        if target.localPoint != nil, window.frame.size != target.frame.size { return nil }
        return Target(pid: window.pid, windowID: window.id, frame: window.frame,
                      localPoint: target.localPoint, source: target.source)
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

    private static func target(for window: Window, elementFrame: CGRect) -> Target? {
        guard contains(elementFrame, in: window.frame) else { return nil }
        let point = CGPoint(x: elementFrame.midX - window.frame.minX,
                            y: elementFrame.midY - window.frame.minY)
        guard CGRect(origin: .zero, size: window.frame.size).contains(point) else { return nil }
        return Target(pid: window.pid, windowID: window.id, frame: window.frame,
                      localPoint: point, source: window.source)
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

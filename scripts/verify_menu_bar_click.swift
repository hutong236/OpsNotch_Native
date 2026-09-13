import AppKit

/// Uses real offscreen AppKit windows without requiring a running menu-bar service.
/// It never sends input to third-party apps. Actual NSStatusItem behavior needs a user session.
@MainActor
final class ProbeClickView: NSView {
    var onEvent: ((NSEvent) -> Void)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onEvent?(event) }
    override func mouseUp(with event: NSEvent) { onEvent?(event) }
    override func rightMouseDown(with event: NSEvent) { onEvent?(event) }
    override func rightMouseUp(with event: NSEvent) { onEvent?(event) }
}

@MainActor
final class ClickProbe: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var item: NSWindow!
    private let clickView = ProbeClickView(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
    private var decoy: NSWindow!
    private var target: MenuBarItemClickForwarder.Target!
    private var primaryCount = 0
    private var secondaryCount = 0
    private var menuCount = 0
    private var decoyCount = 0
    private let menu = NSMenu(title: "Probe menu")
    private var originalCursor = CGPoint.zero

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("PROBE: did finish launching")
        originalCursor = CGEvent(source: nil)?.location ?? .zero
        print("PROBE: creating offscreen windows")
        item = makeWindow(x: -20_000)
        item.contentView = clickView
        clickView.onEvent = { [weak self] event in self?.clicked(event) }
        decoy = makeWindow(x: -21_000)
        let decoyView = ProbeClickView(frame: clickView.frame)
        decoyView.onEvent = { [weak self] _ in self?.decoyCount += 1 }
        decoy.contentView = decoyView
        item.orderFrontRegardless()
        decoy.orderFrontRegardless()
        print("PROBE: created offscreen windows")
        menu.addItem(withTitle: "Probe action", action: nil, keyEquivalent: "")
        menu.delegate = self
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.startChecks() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { self.fail("event delivery timed out") }
    }

    private func startChecks() {
        print("PROBE: reading target window")
        let window = item!
        let initial = MenuBarItemClickForwarder.Target(
            pid: getpid(), windowID: CGWindowID(window.windowNumber), frame: .zero
        )
        guard let current = MenuBarItemClickForwarder.currentTarget(initial) else {
            fail("status-window metadata unavailable")
        }
        target = current
        var count: UInt32 = 0
        require(CGGetActiveDisplayList(0, nil, &count) == .success && count > 0, "display service unavailable")
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displays, &count)
        require(!displays.contains { CGDisplayBounds($0).intersects(current.frame) },
                "fixture must be offscreen: \(current.frame)")
        print("OFFSCREEN_NATIVE_WINDOW window=\(current.windowID) frame=\(current.frame)")

        for interaction in [MenuBarPanelInteraction.primary, .secondary] {
            guard let pair = MenuBarItemClickForwarder.makeEvents(for: current, interaction: interaction),
                  let down = NSEvent(cgEvent: pair.down), let up = NSEvent(cgEvent: pair.up) else {
                fail("could not construct/decode event pair")
            }
            require(down.windowNumber == window.windowNumber && up.windowNumber == window.windowNumber,
                    "decoded events target the wrong window")
            require(down.type == (interaction == .primary ? .leftMouseDown : .rightMouseDown), "wrong down type")
            require(up.type == (interaction == .primary ? .leftMouseUp : .rightMouseUp), "wrong up type")
            require(down.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                    "inherited modifiers")
        }
        let wrongOwner = MenuBarItemClickForwarder.Target(pid: getpid() + 1, windowID: current.windowID, frame: current.frame)
        require(MenuBarItemClickForwarder.currentTarget(wrongOwner) == nil, "mismatched owner accepted")
        // The sender has no NSWindow instance for a third-party window. Exercise that path as
        // well; encoding must not depend on finding the destination in NSApp.windows.
        let foreign = MenuBarItemClickForwarder.Target(pid: getpid() + 1,
            windowID: CGWindowID(Int32.max), frame: current.frame)
        guard let foreignPair = MenuBarItemClickForwarder.makeEvents(for: foreign, interaction: .secondary),
              let foreignDown = NSEvent(cgEvent: foreignPair.down) else { fail("foreign-window encoding failed") }
        require(foreignDown.locationInWindow == NSPoint(x: 14, y: 14),
                "foreign-window coordinates were lost: \(foreignDown.locationInWindow)")
        print("PASS: foreign-window coordinate encoding (no event posted)")
        require(MenuBarItemClickForwarder.post(to: current, interaction: .primary), "primary not submitted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.require(self.primaryCount == 1, "offscreen primary up not received exactly once")
            self.require(self.secondaryCount == 0 && self.decoyCount == 0, "wrong target received primary")
            self.require(MenuBarItemClickForwarder.post(to: current, interaction: .secondary), "secondary not submitted")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.finishChecks() }
        }
    }

    private func makeWindow(x: CGFloat) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: x, y: 400, width: 28, height: 28),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.level = .statusBar
        return window
    }

    private func clicked(_ event: NSEvent) {
        require(event.windowNumber == item.windowNumber, "event reached wrong native window")
        require(clickView.bounds.contains(event.locationInWindow),
                "event has wrong local coordinates: \(event.locationInWindow), bounds: \(clickView.bounds)")
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            break
        case .leftMouseUp:
            primaryCount += 1
        case .rightMouseUp:
            secondaryCount += 1
            let dismiss = Timer(timeInterval: 0.15, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.menu.cancelTracking() }
            }
            RunLoop.main.add(dismiss, forMode: .common)
            menu.popUp(positioning: nil, at: .zero, in: clickView)
        default:
            fail("unexpected native event")
        }
    }

    func menuWillOpen(_ menu: NSMenu) { menuCount += 1 }

    private func finishChecks() {
        require(primaryCount == 1 && secondaryCount == 1 && decoyCount == 0, "incorrect action counts")
        require(menuCount == 1, "native menu did not enter tracking")
        require(MenuBarItemClickForwarder.currentTarget(target)?.frame == target.frame, "item was moved")
        require(CGEvent(source: nil)?.location == originalCursor, "cursor moved")
        item.orderOut(nil)
        decoy.orderOut(nil)
        print("PASS: offscreen left/right actions, native menu tracking, target isolation, unchanged geometry and cursor")
        print("STATUS_ITEMS_NOT_TESTED / THIRD_PARTY_APPS_NOT_TESTED / NOTCH_NOT_TESTED / MULTI_DISPLAY_NOT_TESTED")
        exit(0)
    }

    private func require(_ condition: Bool, _ message: String) {
        if !condition { fail(message) }
    }

    private func fail(_ message: String) -> Never {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct MenuBarClickProbe {
    @MainActor static func main() {
        setbuf(stdout, nil)
        // Keep a watchdog outside AppKit's tracking run loop as well as the CI process timeout.
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
            fputs("FAIL: native tracking watchdog expired\n", stderr)
            exit(1)
        }
        let app = NSApplication.shared
        print("PROBE: application created")
        app.setActivationPolicy(.accessory)
        let delegate = ClickProbe()
        app.delegate = delegate
        print("PROBE: finishing launch")
        app.finishLaunching()
        print("PROBE: starting run loop")
        withExtendedLifetime(delegate) { app.run() }
    }
}

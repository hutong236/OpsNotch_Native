import AppKit

/// This probe uses only its own status items. It never sends input to third-party apps.
@MainActor
final class ClickProbe: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var item: NSStatusItem!
    private var decoy: NSStatusItem!
    private var spacer: NSStatusItem!
    private var target: MenuBarItemClickForwarder.Target!
    private var primaryCount = 0
    private var secondaryCount = 0
    private var menuCount = 0
    private var decoyCount = 0
    private let menu = NSMenu(title: "Probe menu")
    private var originalCursor = CGPoint.zero

    func applicationDidFinishLaunching(_ notification: Notification) {
        originalCursor = CGEvent(source: nil)?.location ?? .zero
        item = NSStatusBar.system.statusItem(withLength: 28)
        item.button?.title = "P"
        item.button?.target = self
        item.button?.action = #selector(clicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        decoy = NSStatusBar.system.statusItem(withLength: 28)
        decoy.button?.title = "D"
        decoy.button?.target = self
        decoy.button?.action = #selector(decoyClicked)
        // A real wide spacer reproduces the app's hiding technique.
        spacer = NSStatusBar.system.statusItem(withLength: 20_000)
        menu.addItem(withTitle: "Probe action", action: nil, keyEquivalent: "")
        menu.delegate = self
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.startChecks() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { self.fail("event delivery timed out") }
    }

    private func startChecks() {
        guard let window = item.button?.window else { fail("status window missing") }
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
        print("OFFSCREEN_STATUS_ITEM window=\(current.windowID) frame=\(current.frame)")

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
        require(MenuBarItemClickForwarder.post(to: current, interaction: .primary), "primary not submitted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.require(self.primaryCount == 1, "offscreen primary action not received exactly once")
            self.require(self.secondaryCount == 0 && self.decoyCount == 0, "wrong target received primary")
            self.require(MenuBarItemClickForwarder.post(to: current, interaction: .secondary), "secondary not submitted")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.finishChecks() }
        }
    }

    @objc private func clicked(_ button: NSStatusBarButton) {
        switch NSApp.currentEvent?.type {
        case .leftMouseUp:
            primaryCount += 1
        case .rightMouseUp:
            secondaryCount += 1
            // A native menu must enter tracking even though its status item remains offscreen.
            let dismiss = Timer(timeInterval: 0.15, repeats: false) { [weak self] _ in
                self?.menu.cancelTracking()
            }
            RunLoop.main.add(dismiss, forMode: .common)
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
        default:
            fail("unexpected status-item event")
        }
    }

    @objc private func decoyClicked() { decoyCount += 1 }

    func menuWillOpen(_ menu: NSMenu) { menuCount += 1 }

    private func finishChecks() {
        require(primaryCount == 1 && secondaryCount == 1 && decoyCount == 0, "incorrect action counts")
        require(menuCount == 1, "native menu did not enter tracking")
        require(spacer.length == 20_000, "hidden region was expanded")
        require(MenuBarItemClickForwarder.currentTarget(target)?.frame == target.frame, "item was moved")
        require(CGEvent(source: nil)?.location == originalCursor, "cursor moved")
        NSStatusBar.system.removeStatusItem(item)
        NSStatusBar.system.removeStatusItem(decoy)
        NSStatusBar.system.removeStatusItem(spacer)
        print("PASS: offscreen left/right actions, native menu tracking, target isolation, unchanged geometry and cursor")
        print("THIRD_PARTY_APPS_NOT_TESTED / NOTCH_NOT_TESTED / MULTI_DISPLAY_NOT_TESTED")
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
        app.setActivationPolicy(.accessory)
        let delegate = ClickProbe()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

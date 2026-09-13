import AppKit
import Darwin

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
        verifyWindowMatching()
        verifyMissingPublicWindow()
        print("PROBE: reading target window")
        let window = item!
        let initial = MenuBarItemClickForwarder.Target(
            pid: getpid(), windowID: CGWindowID(window.windowNumber), frame: .zero
        )
        guard let current = MenuBarItemClickForwarder.currentTarget(initial) else {
            fail("status-window metadata unavailable")
        }
        let inventory = MenuBarWindowServer.menuBarWindows()
        require(inventory.diagnostic.hasPrefix("server-menu-count="),
                "WindowServer menu inventory failed: \(inventory.diagnostic)")
        guard let serverWindow = MenuBarWindowServer.readWindow(current.windowID) else {
            fail("WindowServer owner/frame query failed for own window")
        }
        require(serverWindow.pid == getpid() && serverWindow.frame == current.frame,
                "WindowServer owner/frame differs from own window")
        print("PASS: WindowServer menu inventory and own-window owner/frame queries; \(inventory.diagnostic)")
        // Use an asymmetric inset button so native delivery also checks Quartz/AppKit Y conversion.
        let buttonFrame = CGRect(x: current.frame.minX + 2, y: current.frame.minY + 3, width: 18, height: 16)
        guard let insetTarget = MenuBarItemClickForwarder.match(pid: getpid(), elementFrame: buttonFrame,
            windowID: current.windowID, windows: [serverWindow]) else { fail("live inset target unavailable") }
        require(insetTarget.source == .windowServer, "native probe must revalidate through WindowServer")
        target = insetTarget
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
        let wrongServerOwner = MenuBarItemClickForwarder.Target(pid: getpid() + 1,
            windowID: current.windowID, frame: current.frame, source: .windowServer)
        require(MenuBarItemClickForwarder.currentTarget(wrongServerOwner) == nil, "WindowServer mismatched owner accepted")
        // The sender has no NSWindow instance for a third-party window. Exercise that path as
        // well; encoding must not depend on finding the destination in NSApp.windows.
        let foreign = MenuBarItemClickForwarder.Target(pid: getpid() + 1,
            windowID: CGWindowID(Int32.max), frame: current.frame)
        typealias GetWindowLocation = @convention(c) (CGEvent) -> CGPoint
        guard let image = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let symbol = dlsym(image, "CGEventGetWindowLocation"),
              let foreignPair = MenuBarItemClickForwarder.makeEvents(for: foreign, interaction: .secondary)
              else { fail("foreign-window encoding check unavailable") }
        defer { dlclose(image) }
        let getWindowLocation = unsafeBitCast(symbol, to: GetWindowLocation.self)
        // NSEvent.locationInWindow falls back to screen coordinates for an unknown local
        // window number. Inspect the serialized window point that the receiving process uses.
        require(getWindowLocation(foreignPair.down) == CGPoint(x: 14, y: 14)
                && getWindowLocation(foreignPair.up) == CGPoint(x: 14, y: 14),
                "foreign-window payload lost its local coordinates")
        if let plain = NSEvent.mouseEvent(with: .rightMouseDown, location: NSPoint(x: 14, y: 14),
            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: Int(foreign.windowID), context: nil, eventNumber: 0, clickCount: 1, pressure: 0)?.cgEvent {
            plain.location = CGPoint(x: current.frame.midX, y: current.frame.midY)
            print("PROBE: local point without explicit encoding = \(getWindowLocation(plain))")
        }
        print("PASS: foreign-window coordinate encoding (no event posted)")
        require(MenuBarItemClickForwarder.post(to: insetTarget, interaction: .primary), "primary not submitted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.require(self.primaryCount == 1, "offscreen primary up not received exactly once")
            self.require(self.secondaryCount == 0 && self.decoyCount == 0, "wrong target received primary")
            self.require(MenuBarItemClickForwarder.post(to: insetTarget, interaction: .secondary), "secondary not submitted")
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

    private func verifyWindowMatching() {
        typealias Forwarder = MenuBarItemClickForwarder
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
        let outer = CGRect(x: -20_000, y: 0, width: 44, height: 28)
        // Deliberately asymmetric: clicking the window center is not clicking this AX button.
        let button = CGRect(x: -19_997, y: 2, width: 20, height: 18)
        let window = Forwarder.Window(pid: 101, id: 201, frame: outer, layer: statusLayer)
        let exact = Forwarder.match(pid: 101, elementFrame: outer, windowID: nil, windows: [window])
        require(exact?.windowID == 201, "exact rectangle regression")
        let inset = Forwarder.match(pid: 101, elementFrame: button, windowID: nil, windows: [window])
        require(inset?.localPoint == CGPoint(x: 13, y: 11), "inset AX button could not be matched")
        guard let inset, let pair = Forwarder.makeEvents(for: inset, interaction: .secondary) else {
            fail("inset AX event creation failed")
        }
        require(pair.down.location == CGPoint(x: -19_987, y: 11), "inset click missed AX center")
        let sibling = Forwarder.Window(pid: 101, id: 202, frame: outer, layer: statusLayer)
        require(Forwarder.match(pid: 101, elementFrame: button, windowID: nil, windows: [window, sibling]) == nil,
                "ambiguous geometry selected an arbitrary sibling")
        require(Forwarder.match(pid: 101, elementFrame: button, windowID: 202, windows: [window, sibling])?.windowID == 202,
                "AX window identity did not disambiguate")
        require(Forwarder.match(pid: 102, elementFrame: button, windowID: 201, windows: [window]) == nil,
                "foreign owner accepted by strict identity matching")
        require(Forwarder.match(pid: 101, elementFrame: button, windowID: 999, windows: [window]) == nil,
                "stale AX identity fell back to another window")
        let customLevel = Forwarder.Window(pid: 101, id: 203, frame: outer, layer: statusLayer + 1)
        require(Forwarder.match(pid: 101, elementFrame: button, windowID: 203, windows: [customLevel])?.windowID == 203,
                "authoritative AX identity rejected only by layer")
        require(Forwarder.match(pid: 101, elementFrame: button, windowID: nil, windows: [customLevel]) == nil,
                "unidentified non-status window accepted")
        let outside = button.offsetBy(dx: 100, dy: 0)
        require(Forwarder.match(pid: 101, elementFrame: outside, windowID: 201, windows: [window]) == nil,
                "out-of-window AX coordinates accepted")
        require(Forwarder.match(pid: 101, elementFrame: .zero, windowID: 201, windows: [window]) == nil,
                "invalid AX geometry accepted")
        print("PASS: window matching (insets, negative coordinates, AX identity, owner, layers, ambiguity, stale IDs)")
    }

    private func verifyMissingPublicWindow() {
        typealias Forwarder = MenuBarItemClickForwarder
        // Actual earlier report: public descriptions omitted the hidden status window entirely.
        let ax = CGRect(x: -2980, y: 3, width: 36, height: 24)
        let publicWindows = (0..<8).map { offset in
            Forwarder.Window(pid: 2225, id: CGWindowID(7831 + offset),
                frame: offset < 4 ? CGRect(x: 0, y: 0, width: 2560, height: 30)
                    : CGRect(x: 2560, y: 360, width: 1920, height: 30), layer: 0)
        }
        let hidden = Forwarder.Window(pid: 2225, id: 8000,
            frame: CGRect(x: -2980, y: 0, width: 36, height: 30), layer: 25,
            source: .windowServer)
        var fallbackCalls = 0
        func queries(_ menuWindows: [Forwarder.Window], diagnostic: String = "fixture-inventory") -> Forwarder.WindowQueries {
            Forwarder.WindowQueries(byID: { _ in nil }, publicWindows: { publicWindows }, menuBarWindows: {
                fallbackCalls += 1
                return MenuBarWindowServer.Inventory(windows: menuWindows, diagnostic: diagnostic)
            })
        }
        let result = Forwarder.resolve(pid: 2225, elementFrame: ax, windowID: nil, queries: queries([hidden]))
        guard let target = result.target else { fail("missing-public-window fallback failed: \(result.diagnostic)") }
        require(fallbackCalls == 1 && target.windowID == 8000 && target.source == .windowServer,
                "resolver did not use the menu-bar inventory")
        require(target.localPoint == CGPoint(x: 18, y: 15), "hidden target has wrong local point")
        guard let pair = Forwarder.makeEvents(for: target, interaction: .secondary) else { fail("hidden event creation failed") }
        require(pair.down.location == CGPoint(x: -2962, y: 15), "hidden click missed reported AX center")
        let unavailable = Forwarder.resolve(pid: 2225, elementFrame: ax, windowID: nil,
            queries: queries([], diagnostic: "server-api=unavailable"))
        require(unavailable.target == nil && unavailable.diagnostic.contains("server-api=unavailable")
                && unavailable.diagnostic.contains("public-count=8")
                && unavailable.diagnostic.contains("menu-owner-count=0"), "empty inventory lost failure details")
        let sibling = Forwarder.Window(pid: 2225, id: 8001, frame: hidden.frame, layer: 25,
            source: .windowServer)
        require(Forwarder.resolve(pid: 2225, elementFrame: ax, windowID: nil,
            queries: queries([hidden, sibling])).target == nil, "ambiguous menu inventory selected a window")
        require(Forwarder.resolve(pid: 2225, elementFrame: ax, windowID: 9999,
            queries: queries([hidden])).target == nil, "stale AX identity fell back to a different menu item")
        let nonStatus = Forwarder.Window(pid: 2225, id: 8003, frame: hidden.frame, layer: 0,
            source: .windowServer)
        require(Forwarder.resolve(pid: 2225, elementFrame: ax, windowID: nil,
            queries: queries([nonStatus])).target == nil, "server inventory relaxed the status-window check")

        // Actual 2026-09-13 report after PR #103: AX and the real native status-window have
        // different PIDs even though their offscreen geometry identifies the same menu item.
        let proxyAX = CGRect(x: -3016, y: 3, width: 38, height: 24)
        let proxyPublic = [Forwarder.Window(pid: 75732, id: 7812,
            frame: CGRect(x: 1982, y: 32, width: 295, height: 136), layer: 101)]
        let proxyWindow = Forwarder.Window(pid: 1284, id: 7619,
            frame: CGRect(x: -3015, y: 0, width: 36, height: 30), layer: 25,
            source: .windowServer)
        func proxyQueries(_ menuWindows: [Forwarder.Window]) -> Forwarder.WindowQueries {
            Forwarder.WindowQueries(byID: { _ in nil }, publicWindows: { proxyPublic }, menuBarWindows: {
                MenuBarWindowServer.Inventory(windows: menuWindows,
                    diagnostic: "server-menu-count=26 readable=26 errors=[]")
            })
        }
        let proxyResult = Forwarder.resolve(pid: 75732, elementFrame: proxyAX, windowID: nil,
            queries: proxyQueries([proxyWindow]))
        guard let proxyTarget = proxyResult.target else {
            fail("cross-owner proxy fallback failed: \(proxyResult.diagnostic)")
        }
        require(proxyTarget.pid == 1284 && proxyTarget.windowID == 7619 && proxyTarget.source == .windowServer,
                "proxy target did not preserve the native WindowServer owner")
        require(proxyTarget.localPoint == CGPoint(x: 18, y: 15), "proxy target has wrong local point")
        require(proxyResult.diagnostic.contains("stage=server-proxy-window")
                && proxyResult.diagnostic.contains("ax-pid=75732")
                && proxyResult.diagnostic.contains("window-pid=1284"),
                "proxy resolution lost AX/native owner diagnostics")
        guard let proxyPair = Forwarder.makeEvents(for: proxyTarget, interaction: .secondary) else {
            fail("proxy event creation failed")
        }
        require(proxyPair.down.location == CGPoint(x: -2997, y: 15), "proxy click missed AX center")
        require(proxyPair.down.getIntegerValueField(.eventTargetUnixProcessID) == 1284,
                "proxy event was addressed to the AX PID instead of the native owner")
        require(NSEvent(cgEvent: proxyPair.down)?.windowNumber == 7619,
                "proxy event lost the native destination window")

        let proxySibling = Forwarder.Window(pid: 1285, id: 7620, frame: proxyWindow.frame, layer: 25,
            source: .windowServer)
        let ambiguousProxy = Forwarder.resolve(pid: 75732, elementFrame: proxyAX, windowID: nil,
            queries: proxyQueries([proxyWindow, proxySibling]))
        require(ambiguousProxy.target == nil && ambiguousProxy.diagnostic.contains("proxy-count=2"),
                "ambiguous cross-owner status windows selected an arbitrary target")
        let proxyNonStatus = Forwarder.Window(pid: 1284, id: 7621, frame: proxyWindow.frame, layer: 0,
            source: .windowServer)
        require(Forwarder.resolve(pid: 75732, elementFrame: proxyAX, windowID: nil,
            queries: proxyQueries([proxyNonStatus])).target == nil,
                "cross-owner fallback accepted a non-status window")
        require(Forwarder.resolve(pid: 75732, elementFrame: proxyAX, windowID: 9999,
            queries: proxyQueries([proxyWindow])).target == nil,
                "cross-owner fallback ignored an authoritative stale AX window ID")
        print("PASS: resolver fallback for missing public windows and unique cross-owner status-window proxies")
    }

    private func clicked(_ event: NSEvent) {
        require(event.windowNumber == item.windowNumber, "event reached wrong native window")
        require(clickView.bounds.contains(event.locationInWindow),
                "event has wrong local coordinates: \(event.locationInWindow), bounds: \(clickView.bounds)")
        let expected = CGPoint(x: target.pointInWindow.x, y: target.frame.height - target.pointInWindow.y)
        require(event.locationInWindow == expected,
                "inset event missed button center: \(event.locationInWindow), expected: \(expected)")
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
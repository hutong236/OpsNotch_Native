#if os(macOS)
import AppKit
import ApplicationServices
import Darwin
import Foundation

struct DesktopSpaceDescriptor: Identifiable, Equatable {
    let index: Int
    let spaceID: UInt64
    let displayIdentifier: String
    let displayName: String
    let displayOrder: Int
    let localIndex: Int
    let currentLocalIndex: Int
    let type: Int

    var id: UInt64 { spaceID }
    var isCurrent: Bool { localIndex == currentLocalIndex }
    var isFullscreen: Bool { type == 4 }
}

enum DesktopSpaceSwitchError: Error, Equatable {
    case accessibilityRequired
    case topologyUnavailable
    case desktopNotFound(Int)
    case switchFailed(Int)
}

enum DesktopSpaceSwitchResult {
    case success(DesktopSpaceDescriptor)
    case failure(DesktopSpaceSwitchError)
}

@MainActor
final class DesktopSpaceController {
    fileprivate struct SpaceRecord {
        let id: UInt64
        let type: Int
    }

    fileprivate struct DisplayRecord {
        let identifier: String
        let currentSpaceID: UInt64
        let spaces: [SpaceRecord]
        let originalOrder: Int
    }

    private struct DesktopContext {
        var mousePosition: CGPoint
        var frontmostPID: pid_t?
    }

    private let skyLight = SkyLightSpaceReader()
    private var contexts: [UInt64: DesktopContext] = [:]

    func desktops() -> Result<[DesktopSpaceDescriptor], DesktopSpaceSwitchError> {
        guard let displays = skyLight.managedDisplays() else {
            return .failure(.topologyUnavailable)
        }
        return .success(descriptors(from: displays))
    }

    func switchToDesktop(
        _ index: Int,
        expectedTarget: DesktopSpaceDescriptor? = nil,
        restoreWindowFocus: Bool = true
    ) async -> DesktopSpaceSwitchResult {
        guard await ensureAccessibilityPermission() else {
            return .failure(.accessibilityRequired)
        }

        guard let displays = skyLight.managedDisplays() else {
            return .failure(.topologyUnavailable)
        }

        let currentDescriptors = descriptors(from: displays)
        guard let target = currentDescriptors.first(where: {
            if let expectedTarget {
                return $0.spaceID == expectedTarget.spaceID && $0.displayIdentifier == expectedTarget.displayIdentifier
            }
            return $0.index == index
        }) else {
            return .failure(.desktopNotFound(index))
        }

        captureCurrentContext(from: currentDescriptors)

        guard let targetScreen = screen(matching: target.displayIdentifier),
              let targetDisplayID = targetScreen.opsDirectDisplayID else {
            return .failure(.switchFailed(index))
        }

        let originalPointer = currentQuartzMouseLocation()
        let targetBounds = CGDisplayBounds(targetDisplayID)
        let rememberedPointer = contexts[target.spaceID]?.mousePosition
        let finalPointer = rememberedPointer.map { targetBounds.contains($0) ? $0 : targetBounds.center }
            ?? targetBounds.center

        // Dock routes horizontal Space gestures to the display under the pointer.
        CGWarpMouseCursorPosition(targetBounds.center)

        var switched = target.isCurrent
        if !switched {
            let osMajor = ProcessInfo.processInfo.operatingSystemVersion.majorVersion

            // The classic DockControl field path is known-good through macOS 26.
            // macOS 27 changed the raw IOHID requirements, so go straight to the
            // HID keyboard fallback there instead of risking a stuck gesture.
            if osMajor < 27 {
                postDockSwipe(
                    direction: target.localIndex > target.currentLocalIndex ? 1 : -1,
                    count: abs(target.localIndex - target.currentLocalIndex)
                )
                switched = await waitUntilCurrent(target.spaceID, on: target.displayIdentifier, attempts: 18)
            }

            if !switched {
                switched = await switchUsingHIDFallback(to: target)
            }
        }

        guard switched else {
            CGWarpMouseCursorPosition(originalPointer)
            return .failure(.switchFailed(index))
        }

        CGWarpMouseCursorPosition(finalPointer)
        if restoreWindowFocus {
            focusBestWindow(on: targetDisplayID, forSpaceID: target.spaceID)
        }
        return .success(target)
    }

    private func descriptors(from displays: [DisplayRecord]) -> [DesktopSpaceDescriptor] {
        let screens = NSScreen.screens
        let orderedDisplays = displays.sorted { lhs, rhs in
            let left = screenOrder(for: lhs.identifier, screens: screens) ?? (screens.count + lhs.originalOrder)
            let right = screenOrder(for: rhs.identifier, screens: screens) ?? (screens.count + rhs.originalOrder)
            if left == right { return lhs.originalOrder < rhs.originalOrder }
            return left < right
        }

        var result: [DesktopSpaceDescriptor] = []
        var globalIndex = 1

        for (displayOrder, display) in orderedDisplays.enumerated() {
            let spaces = display.spaces.filter { $0.type == 0 || $0.type == 4 }
            guard !spaces.isEmpty else { continue }
            let currentLocalIndex = spaces.firstIndex(where: { $0.id == display.currentSpaceID }) ?? 0
            let displayName = screen(matching: display.identifier)?.localizedName ?? "Display \(displayOrder + 1)"

            for (localIndex, space) in spaces.enumerated() {
                result.append(
                    DesktopSpaceDescriptor(
                        index: globalIndex,
                        spaceID: space.id,
                        displayIdentifier: display.identifier,
                        displayName: displayName,
                        displayOrder: displayOrder,
                        localIndex: localIndex,
                        currentLocalIndex: currentLocalIndex,
                        type: space.type
                    )
                )
                globalIndex += 1
            }
        }

        return result
    }

    private func captureCurrentContext(from descriptors: [DesktopSpaceDescriptor]) {
        let pointer = currentQuartzMouseLocation()
        let displayID = displayID(containing: pointer)
        let current = descriptors.first { descriptor in
            guard descriptor.isCurrent,
                  let screen = screen(matching: descriptor.displayIdentifier),
                  let candidateID = screen.opsDirectDisplayID else {
                return false
            }
            return candidateID == displayID
        } ?? descriptors.first(where: \.isCurrent)

        guard let current else { return }
        contexts[current.spaceID] = DesktopContext(
            mousePosition: pointer,
            frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier
        )
    }

    private func waitUntilCurrent(
        _ spaceID: UInt64,
        on displayIdentifier: String,
        attempts: Int
    ) async -> Bool {
        for _ in 0..<attempts {
            if skyLight.managedDisplays()?.contains(where: {
                $0.identifier == displayIdentifier && $0.currentSpaceID == spaceID
            }) == true {
                return true
            }
            try? await Task.sleep(nanoseconds: 55_000_000)
        }
        return false
    }

    private func switchUsingHIDFallback(to originalTarget: DesktopSpaceDescriptor) async -> Bool {
        guard let displays = skyLight.managedDisplays() else { return false }
        let refreshed = descriptors(from: displays)
        guard let target = refreshed.first(where: {
            $0.spaceID == originalTarget.spaceID && $0.displayIdentifier == originalTarget.displayIdentifier
        }) else {
            return false
        }
        if target.isCurrent { return true }

        let direction = target.localIndex > target.currentLocalIndex ? 1 : -1
        let count = abs(target.localIndex - target.currentLocalIndex)
        let keyCode: CGKeyCode = direction > 0 ? 124 : 123

        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }

        for _ in 0..<count {
            guard let down = CGEvent(
                keyboardEventSource: source,
                virtualKey: keyCode,
                keyDown: true
            ), let up = CGEvent(
                keyboardEventSource: source,
                virtualKey: keyCode,
                keyDown: false
            ) else {
                return false
            }

            // Mission Control's native Space shortcut is Control + Left/Right.
            // Adding the Fn modifier can change the semantic key event on macOS
            // and makes the HID fallback unreliable.
            let flags: CGEventFlags = .maskControl
            down.flags = flags
            up.flags = flags
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            try? await Task.sleep(nanoseconds: 220_000_000)
        }

        return await waitUntilCurrent(
            target.spaceID,
            on: target.displayIdentifier,
            attempts: 36
        )
    }

    private func postDockSwipe(direction: Int, count: Int) {
        guard count > 0,
              let event = CGEvent(source: nil),
              let eventTypeField = CGEventField(rawValue: 55),
              let hidTypeField = CGEventField(rawValue: 110),
              let motionField = CGEventField(rawValue: 123),
              let progressField = CGEventField(rawValue: 124),
              let velocityField = CGEventField(rawValue: 129),
              let phaseField = CGEventField(rawValue: 132) else {
            return
        }
        let sign = direction > 0 ? 1.0 : -1.0

        event.setIntegerValueField(eventTypeField, value: 30)
        event.setIntegerValueField(hidTypeField, value: 23)
        event.setIntegerValueField(motionField, value: 1)
        event.setDoubleValueField(progressField, value: sign)
        event.setDoubleValueField(velocityField, value: sign * 9999.0)

        for _ in 0..<count {
            event.setIntegerValueField(phaseField, value: 1)
            event.post(tap: .cgSessionEventTap)
            event.setIntegerValueField(phaseField, value: 4)
            event.post(tap: .cgSessionEventTap)
        }
    }

    private func focusBestWindow(on displayID: CGDirectDisplayID, forSpaceID spaceID: UInt64) {
        let bounds = CGDisplayBounds(displayID)
        let preferredPID = contexts[spaceID]?.frontmostPID
        let windows = onScreenWindows(intersecting: bounds)

        let pid: pid_t?
        if let preferredPID, windows.contains(where: { $0.pid == preferredPID }) {
            pid = preferredPID
        } else {
            pid = windows.first?.pid
        }

        guard let pid,
              pid != ProcessInfo.processInfo.processIdentifier,
              let app = NSRunningApplication(processIdentifier: pid) else {
            return
        }

        app.activate(options: [.activateIgnoringOtherApps])

        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        ) == .success,
        let focusedWindow,
        CFGetTypeID(focusedWindow) == AXUIElementGetTypeID() else {
            return
        }

        let windowElement = unsafeBitCast(focusedWindow, to: AXUIElement.self)
        _ = AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString)
    }

    private func onScreenWindows(intersecting displayBounds: CGRect) -> [(pid: pid_t, bounds: CGRect)] {
        guard let raw = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: AnyObject]] else {
            return []
        }

        return raw.compactMap { item in
            guard (item[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  ((item[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0,
                  let pid = (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  pid != ProcessInfo.processInfo.processIdentifier,
                  let boundsDict = item[kCGWindowBounds as String] as? [String: AnyObject] else {
                return nil
            }

            let bounds = CGRect(
                x: CGFloat((boundsDict["X"] as? NSNumber)?.doubleValue ?? 0),
                y: CGFloat((boundsDict["Y"] as? NSNumber)?.doubleValue ?? 0),
                width: CGFloat((boundsDict["Width"] as? NSNumber)?.doubleValue ?? 0),
                height: CGFloat((boundsDict["Height"] as? NSNumber)?.doubleValue ?? 0)
            )
            guard bounds.width > 1, bounds.height > 1, bounds.intersects(displayBounds) else {
                return nil
            }
            return (pid: pid_t(pid), bounds: bounds)
        }
    }

    private func ensureAccessibilityPermission() async -> Bool {
        if AXIsProcessTrusted() { return true }

        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // The system permission sheet/settings flow is asynchronous. Previously
        // we checked again immediately and returned failure, so the first desktop
        // command could only show the permission prompt and never continue.
        // Keep the same command alive for a short window and resume as soon as
        // macOS reports that Accessibility has been granted.
        for _ in 0..<180 {
            if AXIsProcessTrusted() { return true }
            if Task.isCancelled { return false }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        return AXIsProcessTrusted()
    }

    private func currentQuartzMouseLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    private func displayID(containing point: CGPoint) -> CGDirectDisplayID? {
        NSScreen.screens.compactMap(\.opsDirectDisplayID).first {
            CGDisplayBounds($0).contains(point)
        }
    }

    private func screenOrder(for identifier: String, screens: [NSScreen]) -> Int? {
        screens.firstIndex { $0.opsIdentifiers.contains(identifier) }
    }

    private func screen(matching identifier: String) -> NSScreen? {
        NSScreen.screens.first { $0.opsIdentifiers.contains(identifier) }
    }
}

private final class SkyLightSpaceReader {
    typealias ConnectionID = UInt32
    private typealias MainConnectionFunction = @convention(c) () -> ConnectionID
    private typealias CopyManagedDisplaySpacesFunction = @convention(c) (
        ConnectionID
    ) -> Unmanaged<CFArray>?

    private let handle: UnsafeMutableRawPointer?
    private let mainConnection: MainConnectionFunction?
    private let copyManagedDisplaySpaces: CopyManagedDisplaySpacesFunction?

    init() {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        handle = dlopen(path, RTLD_LAZY)

        if let handle,
           let symbol = dlsym(handle, "CGSMainConnectionID") ?? dlsym(handle, "SLSMainConnectionID") {
            mainConnection = unsafeBitCast(symbol, to: MainConnectionFunction.self)
        } else {
            mainConnection = nil
        }

        if let handle,
           let symbol = dlsym(handle, "SLSCopyManagedDisplaySpaces")
                ?? dlsym(handle, "CGSCopyManagedDisplaySpaces") {
            copyManagedDisplaySpaces = unsafeBitCast(
                symbol,
                to: CopyManagedDisplaySpacesFunction.self
            )
        } else {
            copyManagedDisplaySpaces = nil
        }
    }

    func managedDisplays() -> [DesktopSpaceController.DisplayRecord]? {
        guard let mainConnection,
              let copyManagedDisplaySpaces,
              let rawArray = copyManagedDisplaySpaces(mainConnection())?.takeRetainedValue()
        else {
            return nil
        }

        let rawDisplays = (rawArray as NSArray).compactMap { $0 as? [String: Any] }
        return rawDisplays.enumerated().compactMap { order, rawDisplay in
            guard let identifier = rawDisplay["Display Identifier"] as? String,
                  let current = rawDisplay["Current Space"] as? [String: Any],
                  let currentSpaceID = Self.spaceID(from: current) else {
                return nil
            }

            let spaces = (rawDisplay["Spaces"] as? [[String: Any]] ?? []).compactMap {
                rawSpace -> DesktopSpaceController.SpaceRecord? in
                guard let id = Self.spaceID(from: rawSpace) else { return nil }
                let type = (rawSpace["type"] as? NSNumber)?.intValue ?? 0
                return DesktopSpaceController.SpaceRecord(id: id, type: type)
            }

            return DesktopSpaceController.DisplayRecord(
                identifier: identifier,
                currentSpaceID: currentSpaceID,
                spaces: spaces,
                originalOrder: order
            )
        }
    }

    private static func spaceID(from dictionary: [String: Any]) -> UInt64? {
        if let id = (dictionary["ManagedSpaceID"] as? NSNumber)?.uint64Value {
            return id
        }
        return (dictionary["id64"] as? NSNumber)?.uint64Value
    }
}

private extension NSScreen {
    var opsDirectDisplayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
            .map { CGDirectDisplayID($0.uint32Value) }
    }

    var opsDisplayUUIDString: String? {
        guard let opsDirectDisplayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(opsDirectDisplayID)?.takeRetainedValue()
        else {
            return nil
        }
        return CFUUIDCreateString(nil, uuid) as String
    }

    var opsIdentifiers: Set<String> {
        Set([
            opsDirectDisplayID.map(String.init),
            opsDisplayUUIDString
        ].compactMap { $0 })
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
#endif

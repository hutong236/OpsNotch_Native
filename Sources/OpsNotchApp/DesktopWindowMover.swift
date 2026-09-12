#if os(macOS)
import AppKit
import ApplicationServices
import Darwin
import Foundation
import OpsNotchCore
import OpsNotchPrivateInterop
import OSLog

let desktopWindowLog = Logger(subsystem: "lab.hutong.opsnotch", category: "desktop-window")

@MainActor
struct DesktopCapturedWindow {
    let application: NSRunningApplication
    let element: AXUIElement
    let id: CGWindowID
}

enum DesktopWindowMoveError: Error, Equatable {
    case accessibilityRequired, topologyUnavailable, fullscreenUnsupported
    case activeWindowUnavailable, windowIdentifierUnavailable, moveAPIUnavailable
    case singleSpaceRequired, separateSpacesRequired, displayLayoutChanged
    case targetDisplayFullscreen, displayPlacementFailed, focusFailed
    case desktopNotFound(Int), moveFailed(Int), followSwitchFailed(Int)
}

enum DesktopWindowMoveResult {
    case success(DesktopSpaceDescriptor)
    case failure(DesktopWindowMoveError)
}

@MainActor
extension DesktopSpaceController {
    func captureCurrentWindowForMove() -> DesktopCapturedWindow? {
        DesktopWindowMover.shared.captureFrontmostWindow()
    }

    func moveCurrentWindow(
        toDesktop target: DesktopSpaceDescriptor,
        follow: Bool,
        capturedWindow: DesktopCapturedWindow?
    ) async -> DesktopWindowMoveResult {
        guard await DesktopWindowMover.ensureAccessibilityPermission() else { return .failure(.accessibilityRequired) }
        // Never resolve a different frontmost window after the Shelf has taken focus.
        guard let window = capturedWindow else { return .failure(.activeWindowUnavailable) }
        let mover = DesktopWindowMover.shared
        do {
            try await mover.move(window: window, target: target, controller: self)
            let destination = try mover.liveTarget(target, controller: self)
            guard follow else { return .success(destination) }
            let result = await switchToDesktop(destination.index, expectedTarget: destination, restoreWindowFocus: false)
            guard case .success = result else { return .failure(.followSwitchFailed(destination.index)) }
            // Activate only the moved window. The generic desktop focus picker
            // can otherwise select another window/app and switch Spaces again.
            try await mover.focus(window, on: destination, controller: self)
            return .success(destination)
        } catch {
            let finalSpaces = try? mover.spaceIDs(for: window.id)
            let finalFrame = try? mover.windowFrame(window.element)
            desktopWindowLog.error("move failed window=\(window.id, privacy: .public) target=\(target.spaceID, privacy: .public) spaces=\(String(describing: finalSpaces), privacy: .public) frame=\(String(describing: finalFrame), privacy: .public) error=\(String(describing: error), privacy: .public)")
            return .failure(error as? DesktopWindowMoveError ?? .moveFailed(target.index))
        }
    }
}

@MainActor
final class DesktopWindowMover {
    static let shared = DesktopWindowMover()
    private typealias Connection = @convention(c) () -> UInt32
    private typealias LegacyMove = @convention(c) (UInt32, CFArray, UInt64) -> Void
    private typealias ReadSpaces = @convention(c) (UInt32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias WindowID = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private let image: UnsafeMutableRawPointer?
    private let process: UnsafeMutableRawPointer?
    private let connection: Connection?
    private let legacyMove: LegacyMove?
    private let readSpaces: ReadSpaces?
    private let axID: WindowID?

    private init() {
        image = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        process = dlopen(nil, RTLD_LAZY)
        func symbol(_ names: [String], in handle: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
            guard let handle else { return nil }
            return names.lazy.compactMap { dlsym(handle, $0) }.first
        }
        connection = symbol(["SLSMainConnectionID", "CGSMainConnectionID"], in: image).map { unsafeBitCast($0, to: Connection.self) }
        legacyMove = symbol(["SLSMoveWindowsToManagedSpace", "CGSMoveWindowsToManagedSpace"], in: image).map { unsafeBitCast($0, to: LegacyMove.self) }
        readSpaces = symbol(["SLSCopySpacesForWindows", "CGSCopySpacesForWindows"], in: image).map { unsafeBitCast($0, to: ReadSpaces.self) }
        axID = symbol(["_AXUIElementGetWindow"], in: process).map { unsafeBitCast($0, to: WindowID.self) }
    }

    deinit {
        if let process { dlclose(process) }
        if let image { dlclose(image) }
    }

    func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    func captureFrontmostWindow() -> DesktopCapturedWindow? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        // This capture runs before makeKey; do not let an unresponsive app hold
        // up every Quick Shelf invocation for seconds.
        AXUIElementSetMessagingTimeout(appElement, 0.25)
        guard let value = attribute(appElement, kAXFocusedWindowAttribute) ?? attribute(appElement, kAXMainWindowAttribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let element = unsafeBitCast(value, to: AXUIElement.self)
        guard let id = windowID(for: element) else { return nil }
        desktopWindowLog.info("captured source pid=\(app.processIdentifier, privacy: .public) window=\(id, privacy: .public)")
        return DesktopCapturedWindow(application: app, element: element, id: id)
    }

    func windowID(for element: AXUIElement) -> CGWindowID? {
        guard let axID else { return nil }
        var id: CGWindowID = 0
        return axID(element, &id) == .success && id != 0 ? id : nil
    }

    func validateWindow(_ window: DesktopCapturedWindow) throws {
        guard !window.application.isTerminated, windowID(for: window.element) == window.id else {
            throw DesktopWindowMoveError.activeWindowUnavailable
        }
        guard attribute(window.element, "AXFullScreen") as? Bool != true else { throw DesktopWindowMoveError.fullscreenUnsupported }
        guard attribute(window.element, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole,
              attribute(window.element, kAXMinimizedAttribute) as? Bool != true else { throw DesktopWindowMoveError.activeWindowUnavailable }
    }

    func topology(_ controller: DesktopSpaceController) throws -> [DesktopSpaceDescriptor] {
        guard case .success(let descriptors) = controller.desktops() else { throw DesktopWindowMoveError.topologyUnavailable }
        return descriptors
    }

    func liveTarget(_ target: DesktopSpaceDescriptor, controller: DesktopSpaceController) throws -> DesktopSpaceDescriptor {
        guard let live = try topology(controller).first(where: { $0.spaceID == target.spaceID }),
              live.displayIdentifier == target.displayIdentifier else { throw DesktopWindowMoveError.desktopNotFound(target.index) }
        guard live.type == 0 else { throw DesktopWindowMoveError.fullscreenUnsupported }
        return live
    }

    func move(window: DesktopCapturedWindow, target: DesktopSpaceDescriptor, controller: DesktopSpaceController) async throws {
        try validateWindow(window)
        AXUIElementSetMessagingTimeout(window.element, 1)
        let destination = try liveTarget(target, controller: controller)
        let before = try spaceIDs(for: window.id)
        guard before.count == 1, let source = try topology(controller).first(where: { before.contains($0.spaceID) }), source.type == 0 else {
            throw DesktopWindowMoveError.singleSpaceRequired
        }
        if before == [destination.spaceID] { return }
        desktopWindowLog.info("move before window=\(window.id, privacy: .public) spaces=\(String(describing: before), privacy: .public) target=\(destination.spaceID, privacy: .public)")

        let activated = window.application.activate(options: [.activateIgnoringOtherApps])
        let raised = AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        desktopWindowLog.debug("activate window=\(window.id, privacy: .public) activated=\(activated) raise=\(raised.rawValue)")
        try await Task.sleep(nanoseconds: 500_000_000)
        try validateWindow(window)
        _ = try liveTarget(destination, controller: controller)
        guard try spaceIDs(for: window.id) == before else { throw DesktopWindowMoveError.singleSpaceRequired }

        let transfer = try displayTransfer(window: window, source: source, destination: destination)
        if let transfer {
            try await stageOnDisplay(window: window, transfer: transfer, controller: controller)
            _ = try validateTransfer(transfer, controller: controller)
        }
        if try spaceIDs(for: window.id) != [destination.spaceID] {
            try requestMove(windowID: window.id, spaceID: destination.spaceID)
        } else {
            desktopWindowLog.info("display placement reached target window=\(window.id, privacy: .public) target=\(destination.spaceID, privacy: .public)")
        }
        try await verify(window: window, target: destination, transfer: transfer, controller: controller)
    }

    private func requestMove(windowID: CGWindowID, spaceID: UInt64) throws {
        var rawResult: Int64 = 0
        let result = opsnotch_request_window_move(windowID, spaceID, &rawResult)
        if result == 0 {
            desktopWindowLog.info("requested Objective-C move window=\(windowID, privacy: .public) target=\(spaceID, privacy: .public) raw_result=\(rawResult, privacy: .public)")
        } else if result == 1, let connection, let legacyMove {
            // Preserve the classic path when the bridged entry is absent.
            // A failed initializer/exception must not silently switch APIs.
            legacyMove(connection(), [NSNumber(value: Int32(bitPattern: windowID))] as CFArray, spaceID)
            desktopWindowLog.info("requested legacy move window=\(windowID, privacy: .public) target=\(spaceID, privacy: .public)")
        } else {
            desktopWindowLog.error("window move bridge failed code=\(result, privacy: .public)")
            throw DesktopWindowMoveError.moveAPIUnavailable
        }
    }

    func spaceIDs(for windowID: CGWindowID) throws -> Set<UInt64> {
        guard let connection, let readSpaces,
              let raw = readSpaces(connection(), 7, [NSNumber(value: Int32(bitPattern: windowID))] as CFArray)?.takeRetainedValue() else {
            throw DesktopWindowMoveError.topologyUnavailable
        }
        return Set((raw as NSArray).compactMap { ($0 as? NSNumber)?.uint64Value })
    }

    private func verify(window: DesktopCapturedWindow, target: DesktopSpaceDescriptor, transfer: DesktopDisplayTransfer?, controller: DesktopSpaceController) async throws {
        var confirmation = WindowMoveConfirmation(targetSpaceID: target.spaceID)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while clock.now < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
            try validateWindow(window)
            _ = try liveTarget(target, controller: controller)
            var fits = true
            if let transfer {
                _ = try validateTransfer(transfer, controller: controller)
                fits = WindowDisplayGeometry.contains(try windowFrame(window.element), in: transfer.destination.visibleFrame)
            }
            if confirmation.observe(spaceIDs: try spaceIDs(for: window.id), isOnTargetDisplay: fits) {
                desktopWindowLog.info("verified move window=\(window.id, privacy: .public) target=\(target.spaceID, privacy: .public) display=\(target.displayIdentifier, privacy: .public) cross_display=\(transfer != nil)")
                return
            }
        }
        desktopWindowLog.error("move verification timed out window=\(window.id, privacy: .public) target=\(target.spaceID, privacy: .public)")
        throw DesktopWindowMoveError.moveFailed(target.index)
    }

    func focus(_ window: DesktopCapturedWindow, on target: DesktopSpaceDescriptor, controller: DesktopSpaceController) async throws {
        try validateWindow(window)
        guard try spaceIDs(for: window.id) == [target.spaceID] else { throw DesktopWindowMoveError.focusFailed }
        _ = window.application.activate(options: [.activateIgnoringOtherApps])
        let appElement = AXUIElementCreateApplication(window.application.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 1)
        _ = AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, window.element)
        _ = AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while clock.now < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
            try validateWindow(window)
            let destination = try liveTarget(target, controller: controller)
            guard destination.isCurrent, try spaceIDs(for: window.id) == [target.spaceID] else { throw DesktopWindowMoveError.focusFailed }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == window.application.processIdentifier,
               let focused = attribute(appElement, kAXFocusedWindowAttribute), CFGetTypeID(focused) == AXUIElementGetTypeID(),
               windowID(for: unsafeBitCast(focused, to: AXUIElement.self)) == window.id,
               let display = displays().first(where: { $0.identifier == target.displayIdentifier }) {
                let visible = try windowFrame(window.element).intersection(display.visibleFrame)
                guard WindowDisplayGeometry.isUsable(visible) else { throw DesktopWindowMoveError.focusFailed }
                CGWarpMouseCursorPosition(CGPoint(x: visible.midX, y: visible.midY))
                return
            }
        }
        throw DesktopWindowMoveError.focusFailed
    }

    static func ensureAccessibilityPermission() async -> Bool {
        if AXIsProcessTrusted() { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        // Permission cannot retroactively capture the pre-Shelf window. Let the
        // user enable it and summon again with the intended window active.
        return false
    }
}
#endif

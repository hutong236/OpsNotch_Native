#if os(macOS)
import AppKit
import ApplicationServices
import Darwin
import Foundation

enum DesktopWindowMoveError: Error, Equatable {
    case accessibilityRequired
    case topologyUnavailable
    case desktopNotFound(Int)
    case fullscreenUnsupported
    case activeWindowUnavailable
    case windowIdentifierUnavailable
    case moveAPIUnavailable
    case moveFailed(Int)
    case followSwitchFailed(Int)
}

enum DesktopWindowMoveResult {
    case success(DesktopSpaceDescriptor)
    case failure(DesktopWindowMoveError)
}

@MainActor
extension DesktopSpaceController {
    func moveCurrentWindow(toDesktop index: Int, follow: Bool) async -> DesktopWindowMoveResult {
        guard await DesktopWindowMover.ensureAccessibilityPermission() else {
            return .failure(.accessibilityRequired)
        }

        let target: DesktopSpaceDescriptor
        switch desktops() {
        case .failure(let error):
            switch error {
            case .accessibilityRequired:
                return .failure(.accessibilityRequired)
            case .topologyUnavailable:
                return .failure(.topologyUnavailable)
            case .desktopNotFound(let index):
                return .failure(.desktopNotFound(index))
            case .switchFailed(let index):
                return .failure(.followSwitchFailed(index))
            }
        case .success(let descriptors):
            guard let descriptor = descriptors.first(where: { $0.index == index }) else {
                return .failure(.desktopNotFound(index))
            }
            target = descriptor
        }

        guard !target.isFullscreen else {
            return .failure(.fullscreenUnsupported)
        }

        let mover = DesktopWindowMover()
        guard let window = mover.captureFrontmostWindow() else {
            return .failure(.activeWindowUnavailable)
        }
        guard let windowID = mover.windowID(for: window.element) else {
            return .failure(.windowIdentifierUnavailable)
        }
        guard mover.isAvailable else {
            return .failure(.moveAPIUnavailable)
        }
        guard mover.move(windowID: windowID, toSpaceID: target.spaceID) else {
            return .failure(.moveFailed(index))
        }

        guard follow else {
            return .success(target)
        }

        let switchResult = await switchToDesktop(index)
        switch switchResult {
        case .failure:
            return .failure(.followSwitchFailed(index))
        case .success:
            mover.restoreFocus(to: window)
            return .success(target)
        }
    }
}

@MainActor
private final class DesktopWindowMover {
    struct CapturedWindow {
        let application: NSRunningApplication
        let element: AXUIElement
    }

    private typealias ConnectionID = UInt32
    private typealias MainConnectionFunction = @convention(c) () -> ConnectionID
    private typealias MoveWindowsFunction = @convention(c) (ConnectionID, CFArray, UInt64) -> Int32
    private typealias AXWindowIDFunction = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    private let handle: UnsafeMutableRawPointer?
    private let processHandle: UnsafeMutableRawPointer?
    private let mainConnection: MainConnectionFunction?
    private let moveWindows: MoveWindowsFunction?
    private let axWindowID: AXWindowIDFunction?

    init() {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        handle = dlopen(path, RTLD_LAZY)
        processHandle = dlopen(nil, RTLD_LAZY)

        if let handle,
           let symbol = dlsym(handle, "CGSMainConnectionID") ?? dlsym(handle, "SLSMainConnectionID") {
            mainConnection = unsafeBitCast(symbol, to: MainConnectionFunction.self)
        } else {
            mainConnection = nil
        }

        if let handle,
           let symbol = dlsym(handle, "SLSMoveWindowsToManagedSpace")
                ?? dlsym(handle, "CGSMoveWindowsToManagedSpace") {
            moveWindows = unsafeBitCast(symbol, to: MoveWindowsFunction.self)
        } else {
            moveWindows = nil
        }

        if let processHandle,
           let symbol = dlsym(processHandle, "_AXUIElementGetWindow") {
            axWindowID = unsafeBitCast(symbol, to: AXWindowIDFunction.self)
        } else {
            axWindowID = nil
        }
    }

    deinit {
        if let processHandle {
            dlclose(processHandle)
        }
        if let handle {
            dlclose(handle)
        }
    }

    var isAvailable: Bool {
        mainConnection != nil && moveWindows != nil
    }

    func captureFrontmostWindow() -> CapturedWindow? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var value: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        )

        if result != .success || value == nil {
            result = AXUIElementCopyAttributeValue(
                appElement,
                kAXMainWindowAttribute as CFString,
                &value
            )
        }

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        let window = unsafeBitCast(value, to: AXUIElement.self)
        if isFullscreen(window) {
            return nil
        }

        return CapturedWindow(application: application, element: window)
    }

    func windowID(for element: AXUIElement) -> CGWindowID? {
        guard let axWindowID else { return nil }
        var windowID = CGWindowID(0)
        guard axWindowID(element, &windowID) == .success,
              windowID != 0 else {
            return nil
        }
        return windowID
    }

    func move(windowID: CGWindowID, toSpaceID spaceID: UInt64) -> Bool {
        guard let mainConnection, let moveWindows else { return false }
        let windowIDs = [NSNumber(value: windowID)] as CFArray
        return moveWindows(mainConnection(), windowIDs, spaceID) == 0
    }

    func restoreFocus(to window: CapturedWindow) {
        guard !window.application.isTerminated else { return }
        _ = window.application.activate(options: [.activateIgnoringOtherApps])
        _ = AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
    }

    private func isFullscreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            window,
            "AXFullScreen" as CFString,
            &value
        ) == .success else {
            return false
        }
        return (value as? Bool) == true
    }

    static func ensureAccessibilityPermission() async -> Bool {
        if AXIsProcessTrusted() { return true }

        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        for _ in 0..<180 {
            if AXIsProcessTrusted() { return true }
            if Task.isCancelled { return false }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        return AXIsProcessTrusted()
    }
}
#endif

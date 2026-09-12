#if os(macOS)
import AppKit
import ApplicationServices
import Darwin
import Foundation
import OpsNotchPrivateInterop
import OSLog

private let desktopWindowLog = Logger(
    subsystem: "lab.hutong.opsnotch",
    category: "desktop-window"
)

@MainActor
struct DesktopCapturedWindow {
    let application: NSRunningApplication
    let element: AXUIElement
}

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
    func captureCurrentWindowForMove() -> DesktopCapturedWindow? {
        DesktopWindowMover().captureFrontmostWindow()
    }

    func moveCurrentWindow(
        toDesktop index: Int,
        follow: Bool,
        capturedWindow: DesktopCapturedWindow? = nil
    ) async -> DesktopWindowMoveResult {
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
        guard let window = capturedWindow ?? mover.captureFrontmostWindow() else {
            return .failure(.activeWindowUnavailable)
        }
        guard let windowID = mover.windowID(for: window.element) else {
            return .failure(.windowIdentifierUnavailable)
        }
        guard mover.isAvailable else {
            return .failure(.moveAPIUnavailable)
        }
        guard await mover.move(windowID: windowID, toSpaceID: target.spaceID) else {
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
            try? await Task.sleep(nanoseconds: 150_000_000)
            mover.restoreFocus(to: window)
            return .success(target)
        }
    }
}

@MainActor
private final class DesktopWindowMover {
    private typealias ConnectionID = UInt32
    private typealias MainConnectionFunction = @convention(c) () -> ConnectionID
    private typealias MoveWindowsFunction = @convention(c) (ConnectionID, CFArray, UInt64) -> Void
    private typealias PerformBridgedMoveFunction = @convention(c) (UnsafeMutableRawPointer) -> Int64
    private typealias CopySpacesForWindowsFunction = @convention(c) (
        ConnectionID,
        Int32,
        CFArray
    ) -> Unmanaged<CFArray>?
    private typealias AXWindowIDFunction = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    private typealias ObjCGetClassFunction = @convention(c) (UnsafePointer<CChar>) -> UnsafeMutableRawPointer?
    private typealias SelRegisterNameFunction = @convention(c) (UnsafePointer<CChar>) -> UnsafeMutableRawPointer?
    private typealias ObjCMsgSendAllocFunction = @convention(c) (
        UnsafeMutableRawPointer,
        UnsafeMutableRawPointer
    ) -> UnsafeMutableRawPointer?
    private typealias ObjCMsgSendInitMoveFunction = @convention(c) (
        UnsafeMutableRawPointer,
        UnsafeMutableRawPointer,
        CFArray,
        UInt64
    ) -> UnsafeMutableRawPointer?
    private typealias ObjCMsgSendReleaseFunction = @convention(c) (
        UnsafeMutableRawPointer,
        UnsafeMutableRawPointer
    ) -> Void

    private let handle: UnsafeMutableRawPointer?
    private let processHandle: UnsafeMutableRawPointer?
    private let mainConnection: MainConnectionFunction?
    private let moveWindows: MoveWindowsFunction?
    private let performBridgedMove: PerformBridgedMoveFunction?
    private let copySpacesForWindows: CopySpacesForWindowsFunction?
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

        let bridgedMoveSymbol = handle.flatMap {
            dlsym($0, "SLSPerformAsynchronousBridgedWindowManagementOperation")
        } ?? opsnotch_find_macho_symbol(
            "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight",
            "__ZL54SLSPerformAsynchronousBridgedWindowManagementOperationP47SLSAsynchronousBridgedWindowManagementOperation"
        )

        if let symbol = bridgedMoveSymbol {
            performBridgedMove = unsafeBitCast(symbol, to: PerformBridgedMoveFunction.self)
        } else {
            performBridgedMove = nil
        }

        if let handle,
           let symbol = dlsym(handle, "SLSCopySpacesForWindows")
                ?? dlsym(handle, "CGSCopySpacesForWindows") {
            copySpacesForWindows = unsafeBitCast(symbol, to: CopySpacesForWindowsFunction.self)
        } else {
            copySpacesForWindows = nil
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
        mainConnection != nil
            && copySpacesForWindows != nil
            && (performBridgedMove != nil || moveWindows != nil)
    }

    func captureFrontmostWindow() -> DesktopCapturedWindow? {
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

        return DesktopCapturedWindow(application: application, element: window)
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

    func move(windowID: CGWindowID, toSpaceID spaceID: UInt64) async -> Bool {
        let windowIDs = [NSNumber(value: Int32(bitPattern: windowID))] as CFArray
        let sourceSpaces = spaceIDs(for: windowID) ?? []

        if sourceSpaces.contains(spaceID) {
            desktopWindowLog.info(
                "window already belongs to target window=\(windowID, privacy: .public) space=\(spaceID, privacy: .public)"
            )
            return true
        }

        if let performBridgedMove,
           let operationResult = moveUsingBridgedOperation(
               windowIDs: windowIDs,
               spaceID: spaceID,
               perform: performBridgedMove
           ) {
            desktopWindowLog.info(
                "requested bridged move window=\(windowID, privacy: .public) target=\(spaceID, privacy: .public) result=\(operationResult, privacy: .public)"
            )
        } else {
            guard let mainConnection, let moveWindows else { return false }
            moveWindows(mainConnection(), windowIDs, spaceID)
            desktopWindowLog.info(
                "requested legacy move window=\(windowID, privacy: .public) target=\(spaceID, privacy: .public)"
            )
        }

        // Tahoe 26.4+ performs the bridged operation asynchronously. Do not
        // report success until WindowServer confirms the target Space owns the
        // requested window; this prevents the silent no-op seen on macOS 26.
        for _ in 0..<30 {
            if spaceIDs(for: windowID)?.contains(spaceID) == true {
                desktopWindowLog.info(
                    "verified move window=\(windowID, privacy: .public) target=\(spaceID, privacy: .public)"
                )
                return true
            }
            if Task.isCancelled { return false }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        let version = ProcessInfo.processInfo.operatingSystemVersionString
        desktopWindowLog.error(
            "move verification timed out window=\(windowID, privacy: .public) source=\(String(describing: sourceSpaces), privacy: .public) target=\(spaceID, privacy: .public) os=\(version, privacy: .public)"
        )
        return false
    }

    func restoreFocus(to window: DesktopCapturedWindow) {
        guard !window.application.isTerminated else { return }
        _ = window.application.activate(options: [.activateIgnoringOtherApps])
        _ = AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
    }

    private func moveUsingBridgedOperation(
        windowIDs: CFArray,
        spaceID: UInt64,
        perform: PerformBridgedMoveFunction
    ) -> Int64? {
        guard let processHandle,
              let getClassSymbol = dlsym(processHandle, "objc_getClass"),
              let selectorSymbol = dlsym(processHandle, "sel_registerName"),
              let messageSymbol = dlsym(processHandle, "objc_msgSend") else {
            return nil
        }

        let getClass = unsafeBitCast(getClassSymbol, to: ObjCGetClassFunction.self)
        let registerSelector = unsafeBitCast(selectorSymbol, to: SelRegisterNameFunction.self)
        let sendAlloc = unsafeBitCast(messageSymbol, to: ObjCMsgSendAllocFunction.self)
        let sendInit = unsafeBitCast(messageSymbol, to: ObjCMsgSendInitMoveFunction.self)
        let sendRelease = unsafeBitCast(messageSymbol, to: ObjCMsgSendReleaseFunction.self)

        guard let operationClass = "SLSBridgedMoveWindowsToManagedSpaceOperation".withCString({
            getClass($0)
        }),
        let allocSelector = "alloc".withCString({ registerSelector($0) }),
        let initSelector = "initWithWindows:spaceID:".withCString({ registerSelector($0) }),
        let releaseSelector = "release".withCString({ registerSelector($0) }),
        let allocated = sendAlloc(operationClass, allocSelector),
        let operation = sendInit(allocated, initSelector, windowIDs, spaceID) else {
            return nil
        }

        let result = perform(operation)
        sendRelease(operation, releaseSelector)
        return result
    }

    private func spaceIDs(for windowID: CGWindowID) -> Set<UInt64>? {
        guard let mainConnection,
              let copySpacesForWindows else {
            return nil
        }

        let windowIDs = [NSNumber(value: Int32(bitPattern: windowID))] as CFArray
        // 0x7 is kCGSAllSpacesMask: user, other, and current Spaces.
        guard let rawSpaces = copySpacesForWindows(
            mainConnection(),
            0x7,
            windowIDs
        )?.takeRetainedValue() else {
            return nil
        }

        return Set((rawSpaces as NSArray).compactMap {
            ($0 as? NSNumber)?.uint64Value
        })
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

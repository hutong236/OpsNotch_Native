#if os(macOS)
import AppKit
import ApplicationServices
import OpsNotchCore
import OSLog

struct DesktopPhysicalDisplay: Equatable {
    let id: CGDirectDisplayID
    let identifier: String
    let frame: CGRect
    let visibleFrame: CGRect
    let scale: CGFloat
}

struct DesktopDisplayTransfer {
    let layout: [DesktopPhysicalDisplay]
    let destination: DesktopPhysicalDisplay
    let destinationSpace: DesktopSpaceDescriptor
    let originalFrame: CGRect
    let plannedFrame: CGRect
}

@MainActor
extension DesktopWindowMover {
    func displays() -> [DesktopPhysicalDisplay] {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return [] }
        return screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
            return DesktopPhysicalDisplay(id: number.uint32Value, identifier: CFUUIDCreateString(nil, uuid) as String,
                frame: WindowDisplayGeometry.quartzRect(screen.frame, primaryTop: primary.frame.maxY),
                visibleFrame: WindowDisplayGeometry.quartzRect(screen.visibleFrame, primaryTop: primary.frame.maxY),
                scale: screen.backingScaleFactor)
        }
    }

    func windowFrame(_ element: AXUIElement) throws -> CGRect {
        guard let rawPosition = attribute(element, kAXPositionAttribute),
              let rawSize = attribute(element, kAXSizeAttribute),
              CFGetTypeID(rawPosition) == AXValueGetTypeID(), CFGetTypeID(rawSize) == AXValueGetTypeID() else {
            throw DesktopWindowMoveError.displayPlacementFailed
        }
        let position = unsafeBitCast(rawPosition, to: AXValue.self)
        let size = unsafeBitCast(rawSize, to: AXValue.self)
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetType(position) == .cgPoint, AXValueGetType(size) == .cgSize,
              AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &dimensions),
              WindowDisplayGeometry.isUsable(CGRect(origin: point, size: dimensions)) else {
            throw DesktopWindowMoveError.displayPlacementFailed
        }
        return CGRect(origin: point, size: dimensions)
    }

    func displayTransfer(window: DesktopCapturedWindow, source: DesktopSpaceDescriptor, destination: DesktopSpaceDescriptor) throws -> DesktopDisplayTransfer? {
        guard source.displayIdentifier != destination.displayIdentifier else { return nil }
        guard NSScreen.screensHaveSeparateSpaces else { throw DesktopWindowMoveError.separateSpacesRequired }
        let layout = displays()
        guard let from = layout.first(where: { $0.identifier == source.displayIdentifier }),
              let to = layout.first(where: { $0.identifier == destination.displayIdentifier }), from.id != to.id else {
            throw DesktopWindowMoveError.displayLayoutChanged
        }
        let original = try windowFrame(window.element)
        guard let planned = WindowDisplayGeometry.destinationFrame(window: original, source: from.visibleFrame, destination: to.visibleFrame) else {
            throw DesktopWindowMoveError.displayPlacementFailed
        }
        desktopWindowLog.info("cross display plan window=\(window.id, privacy: .public) source_display=\(from.identifier, privacy: .public) target_display=\(to.identifier, privacy: .public) before_frame=\(String(describing: original), privacy: .public) planned_frame=\(String(describing: planned), privacy: .public)")
        return DesktopDisplayTransfer(layout: layout, destination: to, destinationSpace: destination, originalFrame: original, plannedFrame: planned)
    }

    func validateTransfer(_ transfer: DesktopDisplayTransfer, controller: DesktopSpaceController) throws -> [DesktopSpaceDescriptor] {
        guard NSScreen.screensHaveSeparateSpaces, displays() == transfer.layout else { throw DesktopWindowMoveError.displayLayoutChanged }
        _ = try liveTarget(transfer.destinationSpace, controller: controller)
        return try topology(controller)
    }

    func stageOnDisplay(window: DesktopCapturedWindow, transfer: DesktopDisplayTransfer, controller: DesktopSpaceController) async throws {
        let topology = try validateTransfer(transfer, controller: controller)
        guard topology.contains(where: { $0.displayIdentifier == transfer.destination.identifier && $0.isCurrent && $0.type == 0 }) else {
            throw DesktopWindowMoveError.targetDisplayFullscreen
        }
        try Task.checkCancellation()
        try validateWindow(window)
        var canPosition: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(window.element, kAXPositionAttribute as CFString, &canPosition) == .success,
              canPosition.boolValue else { throw DesktopWindowMoveError.displayPlacementFailed }
        var size = transfer.plannedFrame.size
        if size != transfer.originalFrame.size {
            var canResize: DarwinBoolean = false
            guard AXUIElementIsAttributeSettable(window.element, kAXSizeAttribute as CFString, &canResize) == .success,
                  canResize.boolValue, let value = AXValueCreate(.cgSize, &size) else { throw DesktopWindowMoveError.displayPlacementFailed }
            let result = AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, value)
            desktopWindowLog.debug("resize window=\(window.id, privacy: .public) result=\(result.rawValue, privacy: .public)")
            guard result == .success else { throw DesktopWindowMoveError.displayPlacementFailed }
        }
        var point = transfer.plannedFrame.origin
        guard let value = AXValueCreate(.cgPoint, &point) else { throw DesktopWindowMoveError.displayPlacementFailed }
        let result = AXUIElementSetAttributeValue(window.element, kAXPositionAttribute as CFString, value)
        desktopWindowLog.debug("position window=\(window.id, privacy: .public) result=\(result.rawValue, privacy: .public)")
        guard result == .success else { throw DesktopWindowMoveError.displayPlacementFailed }

        var stableSamples = 0
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while clock.now < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
            let currentTopology = try validateTransfer(transfer, controller: controller)
            try validateWindow(window)
            let frame = try windowFrame(window.element)
            let spaces = try spaceIDs(for: window.id)
            let onTargetDisplay = spaces.count == 1 && currentTopology.contains(where: {
                spaces.contains($0.spaceID) && $0.type == 0 && $0.displayIdentifier == transfer.destination.identifier
            })
            stableSamples = onTargetDisplay && WindowDisplayGeometry.contains(frame, in: transfer.destination.visibleFrame) ? stableSamples + 1 : 0
            if stableSamples >= 3 {
                desktopWindowLog.info("display staged window=\(window.id, privacy: .public) spaces=\(String(describing: spaces), privacy: .public) frame=\(String(describing: frame), privacy: .public)")
                return
            }
        }
        throw DesktopWindowMoveError.displayPlacementFailed
    }
}
#endif

import AppKit
import ApplicationServices

struct DemoDisplay: Equatable {
    let id: CGDirectDisplayID
    let identifier: String
    let number: Int
    let name: String
    let frame: CGRect
    let visibleFrame: CGRect
    let scale: CGFloat
}

struct DemoDisplayTransfer {
    let layout: [DemoDisplay]
    let source: DemoDisplay
    let destination: DemoDisplay
    let destinationSpace: DemoSpace
    let originalFrame: CGRect
    let plannedFrame: CGRect
}

@MainActor
extension DemoRuntime {
    func displays() -> [DemoDisplay] {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return [] }
        return screens.enumerated().compactMap { index, screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
            return DemoDisplay(id: number.uint32Value, identifier: CFUUIDCreateString(nil, uuid) as String,
                number: index + 1, name: screen.localizedName,
                frame: DemoGeometry.quartzRect(screen.frame, primaryTop: primary.frame.maxY),
                visibleFrame: DemoGeometry.quartzRect(screen.visibleFrame, primaryTop: primary.frame.maxY),
                scale: screen.backingScaleFactor)
        }
    }

    func windowFrame(_ element: AXUIElement) throws -> CGRect {
        guard let rawPosition = attribute(element, kAXPositionAttribute),
              let rawSize = attribute(element, kAXSizeAttribute),
              CFGetTypeID(rawPosition) == AXValueGetTypeID(), CFGetTypeID(rawSize) == AXValueGetTypeID() else {
            throw DemoFailure("AX_WINDOW_FRAME_UNAVAILABLE")
        }
        let position = unsafeBitCast(rawPosition, to: AXValue.self)
        let size = unsafeBitCast(rawSize, to: AXValue.self)
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetType(position) == .cgPoint, AXValueGetType(size) == .cgSize,
              AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &dimensions),
              DemoGeometry.isUsable(CGRect(origin: point, size: dimensions)) else {
            throw DemoFailure("AX_WINDOW_FRAME_INVALID")
        }
        return CGRect(origin: point, size: dimensions)
    }

    func displayTransfer(window: FinderWindow, source: DemoSpace, destination: DemoSpace) throws -> DemoDisplayTransfer? {
        guard source.display != destination.display else { return nil }
        guard NSScreen.screensHaveSeparateSpaces else {
            throw DemoFailure(tr("跨显示器测试需要开启“显示器具有单独的空间”，并按系统提示重新登录。",
                                 "Enable Displays have separate Spaces and log in again as requested by macOS."))
        }
        let layout = displays()
        guard let from = layout.first(where: { $0.identifier == source.display }),
              let to = layout.first(where: { $0.identifier == destination.display }), from.id != to.id else {
            throw DemoFailure(tr("无法对应源或目标显示器，请刷新后重试。", "Cannot resolve source or destination display. Refresh and retry."))
        }
        let original = try windowFrame(window.element)
        guard let planned = DemoGeometry.destinationFrame(window: original, source: from.visibleFrame, destination: to.visibleFrame) else {
            throw DemoFailure("INVALID_DISPLAY_GEOMETRY")
        }
        log.write("CROSS_DISPLAY_PLAN window=\(window.id) source_display=\(from.identifier) target_display=\(to.identifier) before_frame=\(original) planned_frame=\(planned)")
        return DemoDisplayTransfer(layout: layout, source: from, destination: to, destinationSpace: destination,
                                   originalFrame: original, plannedFrame: planned)
    }

    // Refuse stale geometry after a monitor is removed, rearranged or rescaled.
    // Also refuse a Space which disappeared or moved to a different monitor.
    func validateTransfer(_ transfer: DemoDisplayTransfer) throws -> [DemoSpace] {
        guard NSScreen.screensHaveSeparateSpaces, displays() == transfer.layout else {
            throw DemoFailure(tr("显示器布局已改变，操作已停止；请刷新后重试。", "Display layout changed. Operation stopped; refresh and retry."))
        }
        let topology = try spaces()
        guard topology.contains(where: {
            $0.id == transfer.destinationSpace.id && $0.display == transfer.destination.identifier && $0.type == 0
        }) else {
            throw DemoFailure(tr("目标桌面已改变或被删除，请刷新后重试。", "Destination desktop changed or was removed. Refresh and retry."))
        }
        return topology
    }

    func stageOnDisplay(window: FinderWindow, transfer: DemoDisplayTransfer) async throws {
        let topology = try validateTransfer(transfer)
        guard topology.contains(where: { $0.display == transfer.destination.identifier && $0.current && $0.type == 0 }) else {
            throw DemoFailure(tr("请先将目标显示器从全屏或分屏切回普通桌面，再测试跨屏移动。",
                                 "Switch the destination display out of full screen / Split View to a normal desktop first."))
        }
        guard try identifier(window.element) == window.id else { throw DemoFailure("SELECTED_WINDOW_CHANGED") }
        var canPosition: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(window.element, kAXPositionAttribute as CFString, &canPosition) == .success,
              canPosition.boolValue else { throw DemoFailure("AX_POSITION_NOT_SETTABLE") }
        var size = transfer.plannedFrame.size
        if size != transfer.originalFrame.size {
            var canResize: DarwinBoolean = false
            guard AXUIElementIsAttributeSettable(window.element, kAXSizeAttribute as CFString, &canResize) == .success,
                  canResize.boolValue, let value = AXValueCreate(.cgSize, &size) else {
                throw DemoFailure(tr("窗口大于目标屏幕且无法调整大小。", "The window is larger than the destination and cannot be resized."))
            }
            let result = AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, value)
            log.write("RESIZE window=\(window.id) size=\(size) error=\(result.rawValue)")
            guard result == .success else { throw DemoFailure("AX_RESIZE_FAILED error=\(result.rawValue)") }
        }
        var point = transfer.plannedFrame.origin
        guard let value = AXValueCreate(.cgPoint, &point) else { throw DemoFailure("AX_POSITION_VALUE_FAILED") }
        let result = AXUIElementSetAttributeValue(window.element, kAXPositionAttribute as CFString, value)
        log.write("POSITION window=\(window.id) origin=\(point) error=\(result.rawValue)")
        guard result == .success else { throw DemoFailure("AX_POSITION_FAILED error=\(result.rawValue)") }

        var stableCount = 0
        var previous = ""
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while clock.now < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
            let currentTopology = try validateTransfer(transfer)
            guard try identifier(window.element) == window.id else { throw DemoFailure("SELECTED_WINDOW_CHANGED") }
            let frame = try windowFrame(window.element)
            let spaces = try membership(window.id)
            let onTargetDisplay = spaces.count == 1 && currentTopology.contains(where: {
                spaces.contains($0.id) && $0.type == 0 && $0.display == transfer.destination.identifier
            })
            let state = "spaces=\(spaces.sorted()) frame=\(frame)"
            if state != previous { log.write("STAGING window=\(window.id) \(state)"); previous = state }
            stableCount = onTargetDisplay && DemoGeometry.contains(frame, in: transfer.destination.visibleFrame) ? stableCount + 1 : 0
            if stableCount >= 3 {
                log.write("DISPLAY_STAGED window=\(window.id) \(state) (destination Space still to be verified)")
                return
            }
        }
        throw DemoFailure(tr("未确认窗口完整进入目标显示器，请复制日志。窗口可能已部分移动。",
                             "Could not confirm placement on the destination display. The window may have moved partially; copy the log."))
    }
}

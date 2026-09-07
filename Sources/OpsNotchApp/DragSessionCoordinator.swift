#if os(macOS)
import AppKit
import OpsNotchCore

@MainActor
final class DragSessionCoordinator {
    enum State: Equatable {
        case idle
        case trackingExternalDrag(changeCount: Int, displayID: CGDirectDisplayID)
        case targetVisible(displayID: CGDirectDisplayID)
        case receiving(displayID: CGDirectDisplayID)
        case resolvingPromise(displayID: CGDirectDisplayID)
        case succeeded(displayID: CGDirectDisplayID)
        case cancelling
    }

    private let model: AppModel
    private let shelf: ShelfWindowController
    private let overlay: DragDropOverlayController
    private let dragPasteboard = NSPasteboard(name: .drag)

    private var dragMonitor: Any?
    private var mouseUpMonitor: Any?
    private var baselineChangeCount: Int
    private var currentScreen: NSScreen?
    private var sessionRecognized = false
    private var externalDragActivityNotified = false
    private var successResetWorkItem: DispatchWorkItem?

    private(set) var state: State = .idle
    var dropHandler: ((NativeDropPayload) -> Bool)?
    var promisedFilesHandler: (([URL]) -> Bool)?
    /// Sensor 用它暂停普通 hover 展开，避免 Nearby 与完整 Shelf 在同一 drag session 竞争。
    var onExternalDragActivityChange: ((Bool) -> Void)?

    init(model: AppModel, shelf: ShelfWindowController, overlay: DragDropOverlayController) {
        self.model = model
        self.shelf = shelf
        self.overlay = overlay
        baselineChangeCount = dragPasteboard.changeCount

        overlay.onDragEntered = { [weak self] in
            self?.overlayDidEnter()
        }
        overlay.onDragExited = { [weak self] in
            self?.overlayDidExit()
        }
        overlay.onDrop = { [weak self] payload in
            self?.performOverlayDrop(payload) ?? false
        }
        overlay.onPromiseStarted = { [weak self] in
            self?.overlayPromiseDidStart()
        }
        overlay.onPromisedFiles = { [weak self] urls in
            self?.performPromisedOverlayDrop(urls)
        }
    }

    deinit {
        if let dragMonitor { NSEvent.removeMonitor(dragMonitor) }
        if let mouseUpMonitor { NSEvent.removeMonitor(mouseUpMonitor) }
        successResetWorkItem?.cancel()
    }

    func start() {
        guard dragMonitor == nil, mouseUpMonitor == nil else { return }
        baselineChangeCount = dragPasteboard.changeCount

        let dragMask: NSEvent.EventTypeMask = [.leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: dragMask) { [weak self] _ in
            Task { @MainActor in
                self?.handleExternalDragEvent()
            }
        }

        let upMask: NSEvent.EventTypeMask = [.leftMouseUp, .rightMouseUp, .otherMouseUp]
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: upMask) { [weak self] _ in
            Task { @MainActor in
                self?.handleExternalMouseUp()
            }
        }
    }

    func stop() {
        if let dragMonitor {
            NSEvent.removeMonitor(dragMonitor)
            self.dragMonitor = nil
        }
        if let mouseUpMonitor {
            NSEvent.removeMonitor(mouseUpMonitor)
            self.mouseUpMonitor = nil
        }
        successResetWorkItem?.cancel()
        successResetWorkItem = nil
        overlay.hide()
        sessionRecognized = false
        currentScreen = nil
        state = .idle
        setExternalDragActivity(false)
    }

    /// Shelf/Sensor 的可见性是现有系统拖放链路的事实来源。
    /// 一旦顶部 Sensor 展开 Drop 面板，附近目标立即让位；Sensor 收起而拖拽仍继续时再恢复附近目标。
    func shelfVisibilityDidChange(_ visible: Bool, onDisplayID visibleDisplayID: CGDirectDisplayID?) {
        guard sessionRecognized else { return }

        if visible {
            overlay.hide()
            if let id = visibleDisplayID ?? displayID(of: currentScreen) {
                state = .trackingExternalDrag(changeCount: dragPasteboard.changeCount, displayID: id)
            }
            return
        }

        guard let screen = screenUnderMouse(), let id = displayID(of: screen) else { return }
        currentScreen = screen
        guard nearbyAssistEnabled else {
            overlay.hide()
            state = .trackingExternalDrag(changeCount: dragPasteboard.changeCount, displayID: id)
            return
        }
        overlay.show(near: NSEvent.mouseLocation, on: screen, language: model.language)
        state = .targetVisible(displayID: id)
    }

    private func handleExternalDragEvent() {
        let changeCount = dragPasteboard.changeCount

        if !sessionRecognized {
            guard changeCount != baselineChangeCount else { return }
            baselineChangeCount = changeCount
            guard DropPayloadResolver.canRead(dragPasteboard),
                  let screen = screenUnderMouse(),
                  let id = displayID(of: screen) else { return }

            successResetWorkItem?.cancel()
            successResetWorkItem = nil
            sessionRecognized = true
            currentScreen = screen
            setExternalDragActivity(true)

            if shelf.isPanelVisible || !nearbyAssistEnabled {
                state = .trackingExternalDrag(changeCount: changeCount, displayID: id)
                if shelf.isPanelVisible {
                    dropLog.info("drag assist recognized; shelf already visible")
                } else {
                    dropLog.info("drag assist recognized; sensor-only mode")
                }
            } else {
                overlay.show(near: NSEvent.mouseLocation, on: screen, language: model.language)
                state = .targetVisible(displayID: id)
                dropLog.info("drag assist target visible on display \(id, privacy: .public)")
            }
            return
        }

        guard let screen = screenUnderMouse(), let id = displayID(of: screen) else { return }
        let changedDisplay = displayID(of: currentScreen) != id
        currentScreen = screen

        if shelf.isPanelVisible || !nearbyAssistEnabled {
            if overlay.isVisible { overlay.hide() }
            state = .trackingExternalDrag(changeCount: changeCount, displayID: id)
            return
        }

        // 同屏时目标保持固定，用户才能真正把拖拽物“追上”并放进去；只有跨屏或目标被隐藏时才重新定位。
        if changedDisplay || !overlay.isVisible {
            overlay.show(near: NSEvent.mouseLocation, on: screen, language: model.language)
        }
        state = .targetVisible(displayID: id)
    }

    private func handleExternalMouseUp() {
        switch state {
        case .succeeded:
            sessionRecognized = false
            currentScreen = nil
            baselineChangeCount = dragPasteboard.changeCount
            overlay.hide()
            setExternalDragActivity(false)
        case .resolvingPromise:
            // File Promise 已在 performDragOperation 内启动。鼠标松开是正常 drop 结束，
            // 不能把仍在后台写入的 promise 当作取消，也继续抑制 Sensor hover 直到 promise 完成。
            sessionRecognized = false
            baselineChangeCount = dragPasteboard.changeCount
        default:
            cancelSession()
        }
    }

    private func overlayDidEnter() {
        overlay.setReady(true)
        guard let screen = currentScreen ?? screenUnderMouse(), let id = displayID(of: screen) else { return }
        currentScreen = screen
        state = .receiving(displayID: id)
    }

    private func overlayDidExit() {
        overlay.setReady(false)
        guard sessionRecognized,
              let screen = currentScreen ?? screenUnderMouse(),
              let id = displayID(of: screen) else { return }
        state = .targetVisible(displayID: id)
    }

    private func overlayPromiseDidStart() {
        guard let screen = currentScreen ?? screenUnderMouse(), let id = displayID(of: screen) else { return }
        currentScreen = screen
        sessionRecognized = false
        baselineChangeCount = dragPasteboard.changeCount
        state = .resolvingPromise(displayID: id)
    }

    private func performPromisedOverlayDrop(_ urls: [URL]) {
        let accepted = !urls.isEmpty && (promisedFilesHandler?(urls) ?? false)
        guard accepted else {
            overlay.hide()
            model.showToast(model.language == .zhCN ? "文件接收失败" : "Could not receive promised file")
            currentScreen = nil
            state = .idle
            setExternalDragActivity(false)
            return
        }

        let screen = currentScreen ?? screenUnderMouse() ?? NSScreen.main ?? NSScreen.screens.first
        if let screen {
            finishAcceptedDrop(on: screen)
        } else {
            overlay.hide()
            currentScreen = nil
            state = .idle
            setExternalDragActivity(false)
        }
    }

    private func performOverlayDrop(_ payload: NativeDropPayload) -> Bool {
        let accepted = dropHandler?(payload) ?? false
        guard accepted else {
            cancelSession()
            return false
        }
        let screen = currentScreen ?? screenUnderMouse() ?? NSScreen.main ?? NSScreen.screens.first
        if let screen {
            finishAcceptedDrop(on: screen)
        } else {
            overlay.hide()
            sessionRecognized = false
            state = .idle
            setExternalDragActivity(false)
        }
        return true
    }

    private func finishAcceptedDrop(on screen: NSScreen) {
        overlay.hide()
        overlay.setReady(false)
        currentScreen = screen
        sessionRecognized = false
        baselineChangeCount = dragPasteboard.changeCount
        setExternalDragActivity(false)

        shelf.showPeek(on: screen)
        if model.settings.shelfKeepOpen {
            shelf.scheduleExpanded(on: screen, delay: 0.85)
        } else {
            shelf.scheduleHide(delay: 0.85)
        }

        if let id = displayID(of: screen) {
            state = .succeeded(displayID: id)
        } else {
            state = .idle
            currentScreen = nil
            return
        }

        successResetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if case .succeeded = self.state {
                self.state = .idle
                self.currentScreen = nil
            }
            self.successResetWorkItem = nil
        }
        successResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95, execute: work)
    }

    private func cancelSession() {
        successResetWorkItem?.cancel()
        successResetWorkItem = nil
        state = .cancelling
        overlay.hide()
        overlay.setReady(false)
        sessionRecognized = false
        baselineChangeCount = dragPasteboard.changeCount
        currentScreen = nil
        state = .idle
        setExternalDragActivity(false)
    }

    private func setExternalDragActivity(_ active: Bool) {
        guard externalDragActivityNotified != active else { return }
        externalDragActivityNotified = active
        onExternalDragActivityChange?(active)
    }

    private var nearbyAssistEnabled: Bool {
        model.settings.dragAssistMode == .nearby
    }

    private func screenUnderMouse() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    private func displayID(of screen: NSScreen?) -> CGDirectDisplayID? {
        guard let screen else { return nil }
        return (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
#endif

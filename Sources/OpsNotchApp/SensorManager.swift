#if os(macOS)
import AppKit
import OpsNotchCore
import os

/// 拖放入柜诊断日志(./script/build_and_run.sh --logs 可实时观测)
let dropLog = Logger(subsystem: "lab.hutong.opsnotch", category: "drop")

@MainActor
final class SensorManager {
    private let model: AppModel
    private let shelf: ShelfWindowController
    private let clipboard: ClipboardManager
    private var panels: [CGDirectDisplayID: NSPanel] = [:]
    private var lastActiveDisplayID: CGDirectDisplayID?
    private var observer: NSObjectProtocol?

    init(model: AppModel, shelf: ShelfWindowController, clipboard: ClipboardManager) {
        self.model = model
        self.shelf = shelf
        self.clipboard = clipboard
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rebuild() }
        }
        rebuild()
    }

    func rebuild() {
        let desired = screensForCurrentPolicy()
        let desiredIDs = Set(desired.compactMap(displayID))

        let staleIDs = panels.keys.filter { !desiredIDs.contains($0) }
        for id in staleIDs {
            panels[id]?.close()
            panels[id] = nil
        }

        for screen in desired {
            guard let id = displayID(screen) else { continue }
            let panel = panels[id] ?? makePanel(for: screen, id: id)
            configure(panel: panel, for: screen)
            panels[id] = panel
        }
    }

    func preferredScreen() -> NSScreen? {
        if let id = lastActiveDisplayID,
           let screen = NSScreen.screens.first(where: { displayID($0) == id }) { return screen }
        return screenUnderMouse() ?? primaryScreen() ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func makePanel(for screen: NSScreen, id: CGDirectDisplayID) -> NSPanel {
        let panel = SensorPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true

        let view = SensorView(frame: .zero)
        view.onMouseEnter = { [weak self] in
            guard let self else { return }
            self.lastActiveDisplayID = id
            self.model.reload()
            _ = self.clipboard.catchIfChanged()
            // 不再立即展开完整清单。拖拽进入 Sensor 时 AppKit 会紧接着发送
            // draggingEntered；给它一个很短的优先窗口，避免 expanded 先闪现。
            self.shelf.scheduleExpanded(on: screen, delay: 0.10)
        }
        view.onMouseExit = { [weak self] in
            self?.shelf.cancelScheduledExpand()
            self?.shelf.scheduleHide()
        }
        view.onDragEntered = { [weak self] in
            guard let self else { return }
            self.lastActiveDisplayID = id
            self.shelf.cancelScheduledExpand()
            self.shelf.showDrop(on: screen)
        }
        view.onDragExited = { [weak self] in
            self?.shelf.cancelScheduledExpand()
            self?.shelf.scheduleHide(delay: 0.18)
        }
        view.onDrop = { [weak self] payload in
            guard let self else { return false }
            self.lastActiveDisplayID = id
            self.shelf.cancelScheduledExpand()
            let accepted = self.handle(payload: payload)
            if accepted {
                // 放入后只显示成功反馈，不再展开完整 Shelf。
                self.shelf.showPeek(on: screen)
                self.shelf.scheduleHide(delay: 0.85)
            }
            return accepted
        }
        panel.contentView = view
        panel.orderFrontRegardless()
        return panel
    }

    private func configure(panel: NSPanel, for screen: NSScreen) {
        let height = SensorGeometry.height(for: screen)
        let width = SensorGeometry.width
        let frame = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    private func handle(payload: NativeDropPayload) -> Bool {
        switch payload {
        case .files(let urls):
            model.addPaths(urls)
            return !urls.isEmpty
        case .url(let url):
            model.addURL(url.absoluteString)
            return true
        case .text(let text):
            model.addText(text, toast: false)
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// 入柜处理,供 Sensor 与抽屉窗口拖放接收点(ShelfDropContainerView)共用。
    func handleDrop(payload: NativeDropPayload) -> Bool {
        handle(payload: payload)
    }

    private func screensForCurrentPolicy() -> [NSScreen] {
        switch model.settings.displayTarget {
        case .all: return NSScreen.screens
        case .mouse: return screenUnderMouse().map { [$0] } ?? []
        case .primary: return primaryScreen().map { [$0] } ?? []
        case .current: return preferredScreen().map { [$0] } ?? []
        }
    }

    private func screenUnderMouse() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    private func primaryScreen() -> NSScreen? {
        NSScreen.screens.first { abs($0.frame.origin.x) < 0.5 && abs($0.frame.origin.y) < 0.5 }
            ?? NSScreen.screens.first
    }

    private func displayID(_ screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

final class SensorPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

enum SensorGeometry {
    static let width: CGFloat = 250
    static func height(for screen: NSScreen) -> CGFloat {
        max(38, screen.safeAreaInsets.top)
    }
}

enum NativeDropPayload {
    case files([URL])
    case url(URL)
    case text(String)

    /// Sensor 与抽屉窗口两个拖放接收点共用的可读类型判定与 payload 解析。
    static func canRead(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadObject(forClasses: [NSURL.self, NSString.self], options: nil)
    }

    static func read(from pasteboard: NSPasteboard) -> NativeDropPayload? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL], !objects.isEmpty {
            return .files(objects.map { $0 as URL })
        }
        if let raw = pasteboard.string(forType: .URL),
           let url = URL(string: raw),
           let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            return .url(url)
        }
        if let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            if let url = URL(string: text), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
                return .url(url)
            }
            return .text(text)
        }
        return nil
    }

    /// 日志摘要:只记类型与数量,不落条目内容。
    var logSummary: String {
        switch self {
        case .files(let urls): return "files(\(urls.count))"
        case .url: return "url"
        case .text(let text): return "text(\(text.count))"
        }
    }
}

final class SensorView: NSView {
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onDrop: ((NativeDropPayload) -> Bool)?

    private var tracking: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { onMouseEnter?() }
    override func mouseExited(with event: NSEvent) { onMouseExit?() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEntered?()
        return NativeDropPayload.canRead(sender.draggingPasteboard) ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        NativeDropPayload.canRead(sender.draggingPasteboard) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { onDragExited?() }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let payload = NativeDropPayload.read(from: sender.draggingPasteboard) else {
            dropLog.error("sensor drop: no readable payload")
            return false
        }
        dropLog.info("sensor drop \(payload.logSummary, privacy: .public)")
        return onDrop?(payload) ?? false
    }
}
#endif

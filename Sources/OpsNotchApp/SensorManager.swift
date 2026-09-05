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
    /// Shelf 当前可见性与所在屏:重建面板时据此初始化指示点,重建后状态自愈。
    private var shelfVisible = false
    private var shelfVisibleDisplayID: CGDirectDisplayID?
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
        applyIndicatorState()
    }

    /// Shelf 可见性变化(事件驱动,来自 ShelfWindowController.onVisibilityChange):
    /// 仅隐藏 Shelf 所在屏的指示点,其他屏保持显示。
    func setShelfVisible(_ visible: Bool, onDisplayID: CGDirectDisplayID?) {
        shelfVisible = visible
        shelfVisibleDisplayID = onDisplayID
        applyIndicatorState()
    }

    private func applyIndicatorState() {
        for (id, panel) in panels {
            (panel.contentView as? SensorView)?.showsIndicator = !(shelfVisible && (shelfVisibleDisplayID == nil || shelfVisibleDisplayID == id))
        }
    }

    /// 常驻展开模式启动时选定初始屏：按显示策略取第一块屏。
    func preferredLaunchScreen() -> NSScreen? {
        screensForCurrentPolicy().first ?? preferredScreen()
    }

    /// 指示点在传感器视图内的圆心(视图坐标系,原点左下)。
    /// 传感器高 38pt 而物理刘海深约 32pt:水平正中、距底缘过高都会被刘海挡住,
    /// 故按安全区深度计算——刘海下有可见带时放底部窄带,刘海几乎占满时画在刘海左侧旁。
    private func indicatorDotCenter(for screen: NSScreen) -> CGPoint {
        let height = SensorGeometry.height(for: screen)
        let band = height - screen.safeAreaInsets.top
        let diameter: CGFloat = 4
        if band >= 6 {
            let inset = max(1.5, min(6, (band - diameter) / 2))
            return CGPoint(x: SensorGeometry.width / 2, y: inset + diameter / 2)
        }
        return CGPoint(x: SensorGeometry.width / 2 - 98, y: height / 2)
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
        view.indicatorDotCenter = indicatorDotCenter(for: screen)
        view.onMouseEnter = { [weak self] in
            guard let self else { return }
            self.lastActiveDisplayID = id
            _ = self.clipboard.catchIfChanged()
            // 内存状态即最新(所有写路径实时回写 model),触发路径不做任何磁盘 I/O。
            // 拖拽进入时 AppKit 会紧接着发送 draggingEntered;给它一个很短的优先窗口,
            // 避免 expanded 先闪现。
            self.shelf.scheduleExpanded(on: screen, delay: 0.10)
        }
        view.onMouseExit = { [weak self] in
            guard let self else { return }
            self.shelf.cancelScheduledExpand()
            // 常驻展开模式：移出不触发隐藏调度。
            guard !self.model.settings.shelfKeepOpen else { return }
            self.shelf.scheduleHide()
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
                if self.model.settings.shelfKeepOpen {
                    // 常驻模式：成功反馈展示后重新展开并保持,不调度自动隐藏。
                    self.shelf.scheduleExpanded(on: screen, delay: 0.85)
                } else {
                    self.shelf.scheduleHide(delay: 0.85)
                }
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
            model.captureDroppedURL(url.absoluteString)
            return true
        case .text(let text):
            model.captureDroppedText(text)
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

    /// 收起态入口指示点:仅 Shelf 完全收起时绘制(SensorManager 依可见性事件驱动)。
    /// 纯视觉元素,不改变命中区域语义。
    var showsIndicator = false {
        didSet { needsDisplay = true }
    }
    /// 指示点圆心(视图坐标):由 SensorManager 依屏幕安全区计算,避开物理刘海。
    var indicatorDotCenter = CGPoint(x: 0, y: 2)

    private var tracking: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    /// 指示点样式:深色描边环 + 白色内核,对明暗菜单栏背景都不敏感;复测微调只动这里。
    private enum DotStyle {
        static let coreDiameter: CGFloat = 4
        static let ringOuterDiameter: CGFloat = 6.5
        static let coreAlpha: CGFloat = 0.85
        static let ringAlpha: CGFloat = 0.35
    }

    /// 普通视图 draw 自动按 bounds 裁剪;刻意不开 wantsLayer(layer 内容不裁剪)。
    override func draw(_ dirtyRect: NSRect) {
        guard showsIndicator else { return }
        let center = indicatorDotCenter
        func fillCircle(_ diameter: CGFloat, _ color: NSColor) {
            color.setFill()
            NSBezierPath(
                ovalIn: NSRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
            ).fill()
        }
        fillCircle(DotStyle.ringOuterDiameter, NSColor.black.withAlphaComponent(DotStyle.ringAlpha))
        fillCircle(DotStyle.coreDiameter, NSColor.white.withAlphaComponent(DotStyle.coreAlpha))
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

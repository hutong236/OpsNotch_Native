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

    /// 入口提示中心(视图坐标系,原点左下)。刘海屏将 Sensor 向安全区下方额外延伸，
    /// 提示条优先放在这条无遮挡带中；普通屏继续沿用紧凑入口。
    private func indicatorDotCenter(for screen: NSScreen) -> CGPoint {
        let height = SensorGeometry.height(for: screen)
        let width = SensorGeometry.width(for: screen)
        let band = SensorGeometry.visibleBandHeight(for: screen)
        let indicatorHeight: CGFloat = SensorGeometry.hasCameraHousing(screen) ? 5 : 4
        if band >= indicatorHeight + 2 {
            let inset = max(2, min(8, (band - indicatorHeight) / 2))
            return CGPoint(x: width / 2, y: inset + indicatorHeight / 2)
        }
        return CGPoint(x: width / 2 - min(98, width / 2 - 12), y: height / 2)
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
        view.usesWideIndicator = SensorGeometry.hasCameraHousing(screen)
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
        let width = SensorGeometry.width(for: screen)
        let frame = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
        if let view = panel.contentView as? SensorView {
            view.indicatorDotCenter = indicatorDotCenter(for: screen)
            view.usesWideIndicator = SensorGeometry.hasCameraHousing(screen)
        }
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
    private static let compactWidth: CGFloat = 250
    private static let notchWidth: CGFloat = 360
    private static let minimumHeight: CGFloat = 38
    /// 刘海屏向菜单栏安全区下方延伸一条无遮挡拖放带，避免真正可命中的位置只剩刘海两侧窄缝。
    private static let notchDropReach: CGFloat = 24

    static func hasCameraHousing(_ screen: NSScreen) -> Bool {
        screen.auxiliaryTopLeftArea != nil || screen.auxiliaryTopRightArea != nil
    }

    static func width(for screen: NSScreen) -> CGFloat {
        hasCameraHousing(screen) ? notchWidth : compactWidth
    }

    static func height(for screen: NSScreen) -> CGFloat {
        let base = max(minimumHeight, screen.safeAreaInsets.top)
        return base + (hasCameraHousing(screen) ? notchDropReach : 0)
    }

    static func visibleBandHeight(for screen: NSScreen) -> CGFloat {
        max(0, height(for: screen) - screen.safeAreaInsets.top)
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

    /// 收起态入口指示:仅 Shelf 完全收起时绘制(SensorManager 依可见性事件驱动)。
    /// 纯视觉元素,不改变命中区域语义。
    var showsIndicator = false {
        didSet { needsDisplay = true }
    }
    /// 刘海屏使用短胶囊代替单个小点，显著提高入口可发现性但保持低干扰。
    var usesWideIndicator = false {
        didSet { needsDisplay = true }
    }
    /// 指示中心(视图坐标):由 SensorManager 依屏幕安全区计算,避开物理刘海。
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

    private enum IndicatorStyle {
        static let dotCoreDiameter: CGFloat = 4
        static let dotRingOuterDiameter: CGFloat = 6.5
        static let pillCoreSize = NSSize(width: 36, height: 3.5)
        static let pillRingSize = NSSize(width: 44, height: 7)
        static let coreAlpha: CGFloat = 0.85
        static let ringAlpha: CGFloat = 0.30
    }

    /// 普通视图 draw 自动按 bounds 裁剪;刻意不开 wantsLayer(layer 内容不裁剪)。
    override func draw(_ dirtyRect: NSRect) {
        guard showsIndicator else { return }
        let center = indicatorDotCenter

        if usesWideIndicator {
            func fillPill(_ size: NSSize, _ color: NSColor) {
                color.setFill()
                let rect = NSRect(
                    x: center.x - size.width / 2,
                    y: center.y - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                NSBezierPath(roundedRect: rect, xRadius: size.height / 2, yRadius: size.height / 2).fill()
            }
            fillPill(IndicatorStyle.pillRingSize, NSColor.black.withAlphaComponent(IndicatorStyle.ringAlpha))
            fillPill(IndicatorStyle.pillCoreSize, NSColor.white.withAlphaComponent(IndicatorStyle.coreAlpha))
            return
        }

        func fillCircle(_ diameter: CGFloat, _ color: NSColor) {
            color.setFill()
            NSBezierPath(
                ovalIn: NSRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
            ).fill()
        }
        fillCircle(IndicatorStyle.dotRingOuterDiameter, NSColor.black.withAlphaComponent(IndicatorStyle.ringAlpha))
        fillCircle(IndicatorStyle.dotCoreDiameter, NSColor.white.withAlphaComponent(IndicatorStyle.coreAlpha))
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

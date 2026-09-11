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
    private var panels: [CGDirectDisplayID: NSPanel] = [:]
    private var lastActiveDisplayID: CGDirectDisplayID?
    /// Shelf 当前可见性与所在屏:重建面板时据此初始化指示点,重建后状态自愈。
    private var shelfVisible = false
    private var shelfVisibleDisplayID: CGDirectDisplayID?
    /// Nearby 已识别到外部拖拽时，顶部 Sensor 仍可作为原生 drop destination；
    /// ordinary pointer hover 已禁用，这里只用于协调 Nearby 与顶部 drop UI。
    private var externalDragSessionActive = false
    private var observer: NSObjectProtocol?

    init(model: AppModel, shelf: ShelfWindowController, clipboard _: ClipboardManager) {
        self.model = model
        self.shelf = shelf
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

    /// DragSessionCoordinator 的事件驱动状态，不做额外轮询。
    /// ordinary pointer hover 已禁用；状态只用于避免 Nearby 与顶部 Drop 清单重复出现。
    func setExternalDragSessionActive(_ active: Bool) {
        externalDragSessionActive = active
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

        let view = SensorView(frame: .zero)
        configure(view: view, for: screen)
        view.onDragEntered = { [weak self] in
            guard let self else { return }
            self.lastActiveDisplayID = id
            self.shelf.cancelScheduledExpand()
            // Nearby 模式已经给了明显的大目标时，Sensor 继续可直接 drop，但不再展开另一块 Drop 清单干扰。
            if !(self.externalDragSessionActive && self.model.settings.dragAssistMode == .nearby) {
                self.shelf.showDrop(on: screen)
            }
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
            if accepted { self.showAcceptedDropFeedback(on: screen) }
            return accepted
        }
        view.onPromiseStarted = { [weak self] in
            guard let self else { return }
            self.lastActiveDisplayID = id
            self.shelf.cancelScheduledExpand()
            if !(self.externalDragSessionActive && self.model.settings.dragAssistMode == .nearby) {
                self.shelf.showDrop(on: screen)
            }
            self.model.showToast(self.model.language == .zhCN ? "正在接收文件…" : "Receiving file…")
        }
        view.onPromisedFiles = { [weak self] urls in
            guard let self else { return }
            self.lastActiveDisplayID = id
            let accepted = self.handlePromised(urls: urls)
            if accepted {
                self.showAcceptedDropFeedback(on: screen)
            } else {
                self.model.showToast(self.model.language == .zhCN ? "文件接收失败" : "Could not receive promised file")
                if !self.model.settings.shelfKeepOpen { self.shelf.scheduleHide(delay: 0.5) }
            }
        }
        panel.contentView = view
        panel.orderFrontRegardless()
        return panel
    }

    private func showAcceptedDropFeedback(on screen: NSScreen) {
        // 放入后只显示成功反馈，不再展开完整 Shelf。
        shelf.showPeek(on: screen)
        if model.settings.shelfKeepOpen {
            // 常驻模式：成功反馈展示后重新展开并保持,不调度自动隐藏。
            shelf.scheduleExpanded(on: screen, delay: 0.85)
        } else {
            shelf.scheduleHide(delay: 0.85)
        }
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
            configure(view: view, for: screen)
        }
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    private func configure(view: SensorView, for screen: NSScreen) {
        view.indicatorDotCenter = indicatorDotCenter(for: screen)
        view.usesWideIndicator = SensorGeometry.hasCameraHousing(screen)
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

    private func handlePromised(urls: [URL]) -> Bool {
        !urls.isEmpty && model.addPromisedPaths(urls) > 0
    }

    /// 入柜处理,供 Sensor 与抽屉窗口两个拖放接收点(ShelfDropContainerView)共用。
    func handleDrop(payload: NativeDropPayload) -> Bool {
        handle(payload: payload)
    }

    /// File Promise 入柜处理，供 nearby / Sensor / Shelf 三个落点共用相同存储语义。
    func handlePromisedDrop(urls: [URL]) -> Bool {
        handlePromised(urls: urls)
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
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onDrop: ((NativeDropPayload) -> Bool)?
    var onPromiseStarted: (() -> Void)?
    var onPromisedFiles: (([URL]) -> Void)?

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

    /// 保留一个无业务回调的 tracking area 作为原生 Sensor 结构的一部分；
    /// ordinary pointer hover 不再驱动 Shelf 的显示、隐藏或状态变化。
    private var tracking: NSTrackingArea?
    private var resolvingPromise = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerDropTypes()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerDropTypes()
    }

    private func registerDropTypes() {
        // 保留静态检查要求的基础类型，同时接受 Safari/Photos Promise、浏览器图片与 RTF 文本。
        registerForDraggedTypes([.fileURL, .URL, .string])
        registerForDraggedTypes([.fileURL, .URL, .string] + DropPayloadResolver.extraPasteboardTypes)
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
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard DropPayloadResolver.canRead(sender.draggingPasteboard) else { return [] }
        onDragEntered?()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        DropPayloadResolver.canRead(sender.draggingPasteboard) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        guard !resolvingPromise else { return }
        onDragExited?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let promisedHandler = onPromisedFiles
        return DropPayloadResolver.shared.performDrop(
            from: sender,
            in: self,
            onPromiseStarted: { [weak self] in
                guard let self else { return }
                self.resolvingPromise = true
                self.onPromiseStarted?()
            },
            handleImmediate: { [weak self] payload in
                guard let self else { return false }
                dropLog.info("sensor drop \(payload.logSummary, privacy: .public)")
                return self.onDrop?(payload) ?? false
            },
            handlePromised: { [weak self] urls in
                self?.resolvingPromise = false
                promisedHandler?(urls)
            }
        )
    }
}
#endif

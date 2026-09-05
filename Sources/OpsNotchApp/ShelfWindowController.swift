#if os(macOS)
import AppKit
import QuartzCore
import SwiftUI
import OpsNotchCore

@MainActor
final class ShelfWindowController: NSObject {
    enum Presentation: Equatable {
        case expanded
        case drop
        /// 保留 peek 枚举名兼容现有 ShelfRootView；当前语义是“放入成功反馈”。
        case peek
    }

    private let model: AppModel
    private let clipboard: ClipboardManager
    private let panel: ShelfPanel
    private let dropContainer: ShelfDropContainerView
    private var hostingView: NSHostingView<AnyView>!
    private var currentScreen: NSScreen?
    private var hideWorkItem: DispatchWorkItem?
    private var hoverExpandWorkItem: DispatchWorkItem?
    private var resignObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    private(set) var presentation: Presentation = .expanded
    /// 抽屉窗口拖放入柜处理器,由 AppDelegate 注入(复用 SensorManager 的入柜逻辑)。
    var dropHandler: ((NativeDropPayload) -> Bool)?
    /// Shelf 可见性变化回调(可见?, 所在屏 displayID):供 Sensor 驱动入口指示点,事件驱动、无轮询。
    var onVisibilityChange: ((Bool, CGDirectDisplayID?) -> Void)?
    /// Shelf 当前展示所在屏的 displayID;隐藏时为 nil。
    private(set) var visibleDisplayID: CGDirectDisplayID?

    init(model: AppModel, clipboard: ClipboardManager) {
        self.model = model
        self.clipboard = clipboard
        panel = ShelfPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        dropContainer = ShelfDropContainerView(frame: .zero)
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        hostingView = NSHostingView(rootView: AnyView(ShelfRootView(model: model, clipboard: clipboard, presentation: .expanded)))
        // contentView 用拖放容器包住 SwiftUI 内容:拖到已展开面板/Drop 提示条上松手也入柜,
        // 落点不再只限刘海 Sensor(NSHostingView 自身不处理拖放,事件上溯到容器)。
        dropContainer.onDropPayload = { [weak self] payload in self?.acceptDrop(payload) ?? false }
        dropContainer.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: dropContainer.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: dropContainer.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: dropContainer.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: dropContainer.trailingAnchor),
        ])
        panel.contentView = dropContainer
        panel.orderOut(nil)

        model.shelfHoverChanged = { [weak self] hovered in
            if hovered { self?.cancelHide() } else { self?.scheduleHide(delay: 0.35) }
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.panel.isVisible else { return }
                let menuTracking = NSApp.keyWindow?.level == .popUpMenu
                // 常驻展开模式下失 key 不收起,保留可见。
                // 编辑器 sheet 在展示期间会夺走 key,不能因此把面板连同 sheet 收起。
                if !menuTracking, !self.model.settings.shelfKeepOpen, self.model.editorDraft == nil {
                    self.hide()
                }
            }
        }

        model.requestHide = { [weak self] in self?.hide() }
        model.requestDelayedHide = { [weak self] in self?.scheduleHide(delay: 0.6) }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  self.panel.isKeyWindow,
                  self.presentation == .expanded,
                  self.model.editorDraft == nil else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            switch event.keyCode {
            case 125:
                MainActor.assumeIsolated { self.model.moveHighlight(1) }
                return nil
            case 126:
                MainActor.assumeIsolated { self.model.moveHighlight(-1) }
                return nil
            case 36, 76:
                MainActor.assumeIsolated { self.model.confirmHighlight(using: self.clipboard) }
                return nil
            case 53:
                MainActor.assumeIsolated { self.model.escapeShelf() }
                return nil
            case 48:
                guard modifiers.subtracting([.capsLock, .shift]).isEmpty else { return event }
                if !(self.panel.firstResponder is NSTextView) {
                    MainActor.assumeIsolated { self.model.focusRequestToken = UUID() }
                }
                return nil
            case 18, 19, 20, 21, 23:
                guard modifiers == .command,
                      let index = [18, 19, 20, 21, 23].firstIndex(of: event.keyCode) else { return event }
                let filters: [ShelfKindFilter] = [.all, .file, .text, .url, .application]
                MainActor.assumeIsolated { self.model.setKindFilter(to: filters[index]) }
                return nil
            case 49:
                guard modifiers.subtracting(.capsLock).isEmpty,
                      !(self.panel.firstResponder is NSTextView) else { return event }
                MainActor.assumeIsolated { self.model.quickLookHighlighted() }
                return nil
            default:
                return event
            }
        }
    }

    deinit {
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    /// 普通鼠标进入 Sensor 时略微延迟完整展开，让 draggingEntered 有机会优先接管。
    func scheduleExpanded(on screen: NSScreen, delay: TimeInterval = 0.10) {
        cancelScheduledExpand()
        let work = DispatchWorkItem { [weak self] in
            self?.showExpanded(on: screen)
        }
        hoverExpandWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func cancelScheduledExpand() {
        hoverExpandWorkItem?.cancel()
        hoverExpandWorkItem = nil
    }

    func showExpanded(on screen: NSScreen) {
        show(.expanded, on: screen)
    }

    func showDrop(on screen: NSScreen) {
        show(.drop, on: screen)
    }

    /// 当前用于“✓ 已放入抽屉”成功反馈。
    func showPeek(on screen: NSScreen) {
        show(.peek, on: screen)
    }

    func hide() {
        cancelHide()
        cancelScheduledExpand()
        model.focusRequestToken = nil
        guard panel.isVisible else { return }

        // Drop/Success 像抽屉一样向刘海方向收回；完整 Shelf 保持立即关闭，
        // 避免 Esc/失焦时出现拖沓感。
        guard presentation != .expanded, let screen = currentScreen else {
            panel.orderOut(nil)
            notifyVisibility(false)
            return
        }

        let collapsed = collapsedFrame(for: screen, width: panel.frame.width)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.01 : 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(collapsed, display: true)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak panel, weak self] in
            panel?.orderOut(nil)
            panel?.alphaValue = 1
            // 收起动画结束后再通知,避免指示点与收回动画重叠闪烁。
            Task { @MainActor in self?.notifyVisibility(false) }
        }
    }

    private func notifyVisibility(_ visible: Bool) {
        let nextID = visible ? displayID(of: currentScreen) : nil
        guard nextID != visibleDisplayID else { return }
        visibleDisplayID = nextID
        onVisibilityChange?(visible, nextID)
    }

    private func displayID(of screen: NSScreen?) -> CGDirectDisplayID? {
        guard let screen else { return nil }
        return (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// 全局热键呼出的切换语义:拖放会话(drop 态)忽略;面板可见即收起;
    /// 否则在鼠标所在屏展开并进入键盘流。
    func toggleSummon() {
        guard presentation != .drop else { return }
        if panel.isVisible {
            hide()
        } else {
            showExpanded(on: screenUnderMouse())
        }
    }

    var isPanelVisible: Bool { panel.isVisible }

    /// 抽屉窗口上的落放入柜:成功后显示同款 ✓ 反馈并延时收起。
    private func acceptDrop(_ payload: NativeDropPayload) -> Bool {
        let accepted = dropHandler?(payload) ?? false
        if accepted {
            let screen = currentScreen ?? screenUnderMouse()
            show(.peek, on: screen)
            if model.settings.shelfKeepOpen {
                // 常驻模式：成功反馈展示后重新展开并保持,不调度隐藏。
                scheduleExpanded(on: screen, delay: 0.85)
            } else {
                scheduleHide(delay: 0.85)
            }
        }
        return accepted
    }

    private func screenUnderMouse() -> NSScreen {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
            ?? currentScreen
            ?? NSScreen.main
            ?? NSScreen.screens.first
            ?? NSScreen()
    }

    func scheduleHide(delay: TimeInterval = 0.5) {
        cancelHide()
        // 常驻展开（图钉）模式：所有自动隐藏路径在汇聚点失效；显式隐藏(Esc/取消图钉)走 hide() 直达路径。
        guard !model.settings.shelfKeepOpen else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.model.shelfHovered, self.model.editorDraft == nil else { return }
            let mouseInsidePanel = self.panel.frame.contains(NSEvent.mouseLocation)
            let menuTracking = NSApp.keyWindow?.level == .popUpMenu
            if mouseInsidePanel || menuTracking {
                self.scheduleHide(delay: 0.35)
                return
            }
            self.hide()
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func cancelHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    private func show(_ state: Presentation, on screen: NSScreen) {
        cancelHide()
        cancelScheduledExpand()
        let wasVisible = panel.isVisible
        let previousState = presentation

        presentation = state
        currentScreen = screen
        model.focusRequestToken = (state == .expanded) ? UUID() : nil
        hostingView.rootView = rootView(for: state)

        let targetFrame = frame(for: state, on: screen)
        if state == .drop && !wasVisible {
            // 真正的“抽屉向下展开”：顶部锚定在 Sensor 下沿，高度从 8pt 展开到 112pt。
            let collapsed = collapsedFrame(for: screen, width: targetFrame.width)
            panel.alphaValue = 0
            panel.setFrame(collapsed, display: false)
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.01 : 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(targetFrame, display: true)
                panel.animator().alphaValue = 1
            }
        } else if wasVisible && previousState != state && state != .expanded {
            // Drop → Success：轻微收束，不展开完整列表。
            NSAnimationContext.runAnimationGroup { context in
                context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.01 : 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(targetFrame, display: true)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.alphaValue = 1
            panel.setFrame(targetFrame, display: true)
            panel.orderFrontRegardless()
        }

        if state == .expanded {
            panel.makeKey()
        }
        notifyVisibility(true)
    }

    private func rootView(for state: Presentation) -> AnyView {
        switch state {
        case .expanded, .drop:
            return AnyView(ShelfRootView(model: model, clipboard: clipboard, presentation: state))
        case .peek:
            return AnyView(DropSuccessFeedbackView(language: model.language))
        }
    }

    private func frame(for state: Presentation, on screen: NSScreen) -> NSRect {
        let size = size(for: state)
        let sensorHeight = SensorGeometry.height(for: screen)
        return NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - sensorHeight - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func collapsedFrame(for screen: NSScreen, width: CGFloat) -> NSRect {
        let sensorHeight = SensorGeometry.height(for: screen)
        let height: CGFloat = 8
        return NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - sensorHeight - height,
            width: width,
            height: height
        )
    }

    private func size(for state: Presentation) -> NSSize {
        switch state {
        case .expanded: return NSSize(width: 440, height: 560)
        case .drop: return NSSize(width: 350, height: 112)
        case .peek: return NSSize(width: 320, height: 68)
        }
    }
}

/// 放入完成后的唯一反馈：不展示 Pinned/Recent，也不暴露完整清单。
private struct DropSuccessFeedbackView: View {
    let language: AppLanguage

    private var title: String { language == .zhCN ? "已放入抽屉" : "Added to Shelf" }
    private var hint: String { language == .zhCN ? "已保存，可稍后从 Ops Notch 取用" : "Saved. You can retrieve it from Ops Notch later." }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(hint)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .padding(6)
    }
}

final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 抽屉窗口的拖放接收容器:SwiftUI 内容(NSHostingView)不处理拖放,
/// 拖放事件上溯到本容器统一入柜,与 SensorView 共用 NativeDropPayload 管线。
final class ShelfDropContainerView: NSView {
    var onDropPayload: ((NativeDropPayload) -> Bool)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        NativeDropPayload.canRead(sender.draggingPasteboard) ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        NativeDropPayload.canRead(sender.draggingPasteboard) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let payload = NativeDropPayload.read(from: sender.draggingPasteboard) else {
            dropLog.error("shelf drop: no readable payload")
            return false
        }
        dropLog.info("shelf drop \(payload.logSummary, privacy: .public)")
        return onDropPayload?(payload) ?? false
    }
}
#endif

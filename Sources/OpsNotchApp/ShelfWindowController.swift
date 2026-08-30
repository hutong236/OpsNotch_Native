#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

@MainActor
final class ShelfWindowController: NSObject {
    enum Presentation: Equatable {
        case expanded
        case drop
        case peek
    }

    private let model: AppModel
    private let clipboard: ClipboardManager
    private let panel: ShelfPanel
    private let dropContainer: ShelfDropContainerView
    private var hostingView: NSHostingView<ShelfRootView>!
    private var currentScreen: NSScreen?
    private var hideWorkItem: DispatchWorkItem?
    private var resignObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    private(set) var presentation: Presentation = .expanded
    /// 抽屉窗口拖放入柜处理器,由 AppDelegate 注入(复用 SensorManager 的入柜逻辑)。
    var dropHandler: ((NativeDropPayload) -> Bool)?

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

        hostingView = NSHostingView(rootView: ShelfRootView(model: model, clipboard: clipboard, presentation: .expanded))
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

        // 键盘取回流需要面板成为 key 窗;失焦(切走应用/点了别的窗口)时立即收起,
        // 避免 accessory 应用留下一块失焦浮窗。右键菜单追踪期豁免(菜单会短暂夺走 key 状态)。
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.panel.isVisible else { return }
                let menuTracking = NSApp.keyWindow?.level == .popUpMenu
                if !menuTracking { self.hide() }
            }
        }

        // 键盘取回流:面板为 key 窗且处于 expanded 态时,接管 ↑↓/Enter/Esc/⌘1~⌘5/Space。
        // 本地 monitor(AppKit 层)而非 SwiftUI onKeyPress——后者要求 macOS 14,项目门槛是 13。
        model.requestHide = { [weak self] in self?.hide() }
        model.requestDelayedHide = { [weak self] in self?.scheduleHide(delay: 0.6) }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  self.panel.isKeyWindow,
                  self.presentation == .expanded,
                  self.model.editorDraft == nil else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            switch event.keyCode {
            case 125: // ↓
                MainActor.assumeIsolated { self.model.moveHighlight(1) }
                return nil
            case 126: // ↑
                MainActor.assumeIsolated { self.model.moveHighlight(-1) }
                return nil
            case 36, 76: // Return / 小键盘 Enter
                MainActor.assumeIsolated { self.model.confirmHighlight(using: self.clipboard) }
                return nil
            case 53: // Esc
                MainActor.assumeIsolated { self.model.escapeShelf() }
                return nil
            case 48: // Tab 回到搜索:焦点不在文本框时把焦点交回搜索框(键盘流闭环);
                     // 已在搜索框(field editor)则消费,防止 Tab 默认焦点环把焦点移出键盘流。
                     // ⇧Tab 与 Tab 同义;编辑草稿态已被顶部 guard 整体放行。
                guard modifiers.subtracting([.capsLock, .shift]).isEmpty else { return event }
                if !(self.panel.firstResponder is NSTextView) {
                    MainActor.assumeIsolated { self.model.focusRequestToken = UUID() }
                }
                return nil
            case 18, 19, 20, 21, 23: // ⌘1~⌘5 切换类型筛选
                guard modifiers == .command,
                      let index = [18, 19, 20, 21, 23].firstIndex(of: event.keyCode) else { return event }
                let filters: [ShelfKindFilter] = [.all, .file, .text, .url, .application]
                MainActor.assumeIsolated { self.model.setKindFilter(to: filters[index]) }
                return nil
            case 49: // Space 预览高亮条目;搜索框聚焦(field editor)时放行为普通输入
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

    func showExpanded(on screen: NSScreen) {
        show(.expanded, on: screen)
    }

    func showDrop(on screen: NSScreen) {
        show(.drop, on: screen)
    }

    func showPeek(on screen: NSScreen) {
        show(.peek, on: screen)
    }

    func hide() {
        cancelHide()
        panel.orderOut(nil)
        model.focusRequestToken = nil
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

    /// 抽屉窗口上的落放入柜:成功后与 Sensor 落放同款反馈(peek 确认 + 延时收起)。
    private func acceptDrop(_ payload: NativeDropPayload) -> Bool {
        let accepted = dropHandler?(payload) ?? false
        if accepted {
            show(.peek, on: currentScreen ?? screenUnderMouse())
            scheduleHide(delay: 0.9)
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
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.model.shelfHovered, self.model.editorDraft == nil else { return }
            // 右键菜单打开时,菜单窗口遮住面板会让 hover 状态失同步,菜单项也可能下探出面板 frame;
            // 此时暂缓隐藏、稍后重查,避免把正在使用的菜单(如"取消置顶")连同面板一起收起。
            let mouseInsidePanel = self.panel.frame.contains(NSEvent.mouseLocation)
            let menuTracking = NSApp.keyWindow?.level == .popUpMenu
            if mouseInsidePanel || menuTracking {
                self.scheduleHide(delay: 0.35)
                return
            }
            self.panel.orderOut(nil)
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
        presentation = state
        currentScreen = screen
        // expanded 展开(无论悬停还是热键触发)都发一次焦点请求,搜索框自动聚焦;
        // drop/peek 清掉残留请求。面板隐藏时(hide())同样清空。
        model.focusRequestToken = (state == .expanded) ? UUID() : nil
        hostingView.rootView = ShelfRootView(model: model, clipboard: clipboard, presentation: state)

        let size = size(for: state)
        let sensorHeight = SensorGeometry.height(for: screen)
        let frame = NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - sensorHeight - size.height,
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        // 键盘流:expanded 展开即接管键盘(面板成为 key 窗但不激活 App,焦点回到
        // 搜索框供直接输入);drop/peek 态不抢焦点、不干扰拖放。
        if state == .expanded {
            panel.makeKey()
        }
    }

    private func size(for state: Presentation) -> NSSize {
        switch state {
        case .expanded: return NSSize(width: 440, height: 560)
        case .drop: return NSSize(width: 350, height: 112)
        case .peek: return NSSize(width: 320, height: 64)
        }
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

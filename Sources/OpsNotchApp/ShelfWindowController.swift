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
    private var hostingView: NSHostingView<ShelfRootView>!
    private var currentScreen: NSScreen?
    private var hideWorkItem: DispatchWorkItem?
    private(set) var presentation: Presentation = .expanded

    init(model: AppModel, clipboard: ClipboardManager) {
        self.model = model
        self.clipboard = clipboard
        panel = ShelfPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
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
        panel.contentView = hostingView
        panel.orderOut(nil)

        model.shelfHoverChanged = { [weak self] hovered in
            if hovered { self?.cancelHide() } else { self?.scheduleHide(delay: 0.35) }
        }
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
#endif

#if os(macOS)
import AppKit
import OpsNotchCore

/// NSDraggingSource 与 SwiftUI/AppModel 之间的单一生命周期桥。
/// AppDelegate 启动时绑定一次 model；拖动视图只上报 AppKit 的最终 operation，
/// 不自行决定 Shelf 删除、Recall 或 UI 反馈。
@MainActor
final class DragOutLifecycleCoordinator {
    static let shared = DragOutLifecycleCoordinator()

    private weak var model: AppModel?
    private var keyMonitor: Any?

    private init() {}

    func bind(model: AppModel) {
        self.model = model
        installRecallShortcutIfNeeded()
    }

    func draggingEnded(items: [ShelfItem], operation: NSDragOperation) {
        model?.handleDragOutEnded(items: items, operation: operation)
    }

    private func installRecallShortcutIfNeeded() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 6, // Z
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  NSApp.keyWindow is ShelfPanel,
                  !(NSApp.keyWindow?.firstResponder is NSTextView) else {
                return event
            }
            MainActor.assumeIsolated {
                self?.model?.recallLastDragOut()
            }
            return nil
        }
    }
}
#endif

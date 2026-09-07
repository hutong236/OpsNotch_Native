#if os(macOS)
import AppKit
import OpsNotchCore

@MainActor
extension AppModel {
    /// AppKit 已经给出最终 drag operation 后才改变 Shelf 状态。
    /// 取消/失败(operation == [])不做任何删除；Pinned 与 Working Set 视为用户明确保护的条目，成功拖出也保留。
    func handleDragOutEnded(items draggedItems: [ShelfItem], operation: NSDragOperation) {
        guard !operation.isEmpty else {
            dropLog.info("drag-out ended cancelled count=\(draggedItems.count, privacy: .public)")
            return
        }

        let protectedIDs = Set(settings.workingSetItemIDs)
        let removable = draggedItems.filter { item in
            !item.pinned && !protectedIDs.contains(item.id)
        }

        guard !removable.isEmpty else {
            dropLog.info(
                "drag-out ended success operation=\(operation.rawValue, privacy: .public) retained=\(draggedItems.count, privacy: .public)"
            )
            return
        }

        do {
            let value = try DragOutRecallCoordinator.shared.consume(items: removable, store: store)
            apply(value)
            let removedIDs = Set(removable.map(\.id))
            selection.subtract(removedIDs)
            dropLog.info(
                "drag-out consumed operation=\(operation.rawValue, privacy: .public) removed=\(removable.count, privacy: .public) retained=\(draggedItems.count - removable.count, privacy: .public)"
            )
            showToast(language == .zhCN ? "已从暂存区移除，⌘Z 可撤销" : "Removed from Shelf. Press ⌘Z to undo.")
        } catch {
            dropLog.error("drag-out cleanup failed")
            showToast(error.localizedDescription)
        }
    }

    func recallLastDragOut() {
        do {
            guard let value = try DragOutRecallCoordinator.shared.recall(store: store) else { return }
            apply(value)
            showToast(language == .zhCN ? "已恢复上次拖出的条目" : "Restored the last drag-out.")
            dropLog.info("drag-out recall restored")
        } catch {
            dropLog.error("drag-out recall failed")
            showToast(error.localizedDescription)
        }
    }

    func cleanupStaleDragOutRecallStorage() {
        DragOutRecallCoordinator.shared.cleanupStaleStorage(store: store)
    }
}
#endif

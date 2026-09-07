#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

struct NativeDragSourceView: NSViewRepresentable {
    let items: [ShelfItem]

    func makeNSView(context: Context) -> DragSourceNSView {
        let view = DragSourceNSView()
        view.items = items
        return view
    }

    func updateNSView(_ nsView: DragSourceNSView, context: Context) {
        nsView.items = items
    }
}

final class DragSourceNSView: NSView, NSDraggingSource {
    var items: [ShelfItem] = []

    private var mouseDownEvent: NSEvent?
    private var activeSessionItems: [ShelfItem] = []

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard mouseDownEvent != nil, !items.isEmpty else { return }

        var sourceItems: [ShelfItem] = []
        var draggingItems: [NSDraggingItem] = []
        for item in items {
            guard let draggingItem = makeDraggingItem(item) else { continue }
            sourceItems.append(item)
            draggingItems.append(draggingItem)
        }
        guard !draggingItems.isEmpty else { return }

        activeSessionItems = sourceItems
        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        mouseDownEvent = nil
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "Drag")
        image?.draw(in: bounds.insetBy(dx: 2, dy: 2), from: .zero, operation: .sourceOver, fraction: 0.45)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        switch context {
        case .withinApplication:
            // Ops Notch 内部没有 reorder/drop-back 语义；禁止把 Shelf 条目重新拖回自身导致重复入柜。
            return []
        case .outsideApplication:
            // path-backed 条目必须保持 copy-only：开放 move 会允许 Finder 直接搬走原文件，
            // 从而使 reference 或受管 Shelf 路径失效。纯文本/URL 没有底层文件可被搬走，
            // 可以安全让目标在 copy/move 之间协商。
            let containsPathBackedItem = activeSessionItems.contains {
                [.file, .folder, .application].contains($0.kind)
            }
            return containsPathBackedItem ? .copy : [.copy, .move]
        @unknown default:
            return .copy
        }
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        let completedItems = activeSessionItems
        activeSessionItems = []
        mouseDownEvent = nil
        DragOutLifecycleCoordinator.shared.draggingEnded(items: completedItems, operation: operation)
    }

    private func makeDraggingItem(_ item: ShelfItem) -> NSDraggingItem? {
        let writer: NSPasteboardWriting
        let image: NSImage
        switch item.kind {
        case .file, .folder, .application:
            let url = URL(fileURLWithPath: item.content)
            writer = url as NSURL
            image = NSWorkspace.shared.icon(forFile: item.content)
        case .url:
            guard let url = URL(string: item.content) else { return nil }
            writer = url as NSURL
            image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
                ?? NSImage(size: NSSize(width: 24, height: 24))
        case .text, .action:
            writer = item.content as NSString
            image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
                ?? NSImage(size: NSSize(width: 24, height: 24))
        }
        let drag = NSDraggingItem(pasteboardWriter: writer)
        drag.setDraggingFrame(
            NSRect(x: bounds.midX - 16, y: bounds.midY - 16, width: 32, height: 32),
            contents: image
        )
        return drag
    }
}
#endif

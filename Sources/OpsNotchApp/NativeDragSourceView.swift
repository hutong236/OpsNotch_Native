#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

/// Native AppKit drag source retained so we can observe the final NSDragOperation.
/// The view can now cover the row's primary content instead of requiring a tiny 16x18 handle.
struct NativeDragSourceView: NSViewRepresentable {
    let items: [ShelfItem]
    var onClick: (() -> Void)? = nil
    var showsHandle: Bool = true

    func makeNSView(context: Context) -> DragSourceNSView {
        let view = DragSourceNSView()
        view.items = items
        view.onClick = onClick
        view.showsHandle = showsHandle
        return view
    }

    func updateNSView(_ nsView: DragSourceNSView, context: Context) {
        nsView.items = items
        nsView.onClick = onClick
        nsView.showsHandle = showsHandle
        nsView.needsDisplay = true
    }
}

final class DragSourceNSView: NSView, NSDraggingSource {
    var items: [ShelfItem] = []
    var onClick: (() -> Void)?
    var showsHandle = true

    private var mouseDownEvent: NSEvent?
    private var activeSessionItems: [ShelfItem] = []
    private var didStartDrag = false

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        didStartDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard mouseDownEvent != nil, !didStartDrag, !items.isEmpty else { return }

        var sourceItems: [ShelfItem] = []
        var draggingItems: [NSDraggingItem] = []
        for item in items {
            guard let draggingItem = makeDraggingItem(item) else { continue }
            sourceItems.append(item)
            draggingItems.append(draggingItem)
        }
        guard !draggingItems.isEmpty else { return }

        didStartDrag = true
        activeSessionItems = sourceItems
        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        mouseDownEvent = nil
    }

    override func mouseUp(with event: NSEvent) {
        let shouldClick = mouseDownEvent != nil && !didStartDrag
        mouseDownEvent = nil
        didStartDrag = false
        if shouldClick { onClick?() }
    }

    /// SwiftUI contextMenu 仍挂在外层 row；透明 AppKit drag overlay 收到右键时把事件交回宿主链路。
    override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard showsHandle else { return }
        let image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "Drag")
        image?.draw(in: bounds.insetBy(dx: 2, dy: 2), from: .zero, operation: .sourceOver, fraction: 0.45)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        switch context {
        case .withinApplication:
            // Ops Notch 内部没有 reorder/drop-back 语义；禁止把 Shelf 条目重新拖回自身导致重复入柜。
            return []
        case .outsideApplication:
            // path-backed 条目保持 copy-only，避免 Finder 直接搬走 reference/managed file。
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
        didStartDrag = false
        DragOutLifecycleCoordinator.shared.draggingEnded(items: completedItems, operation: operation)
    }

    private func makeDraggingItem(_ item: ShelfItem) -> NSDraggingItem? {
        let writer: NSPasteboardWriting
        let image: NSImage
        switch item.kind {
        case .file, .folder, .application:
            let url = URL(fileURLWithPath: item.content).standardizedFileURL
            // NSURL 本身在部分目标（尤其 Terminal）可能被协商成临时文件表示。
            // 显式同时提供 fileURL + legacy filenames + plain absolute path，确保 Terminal 插入真实路径，
            // Finder 仍按真实 file URL 进行文件复制。
            writer = FilePathDragWriter(url: url)
            image = NSWorkspace.shared.icon(forFile: url.path)
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
            NSRect(x: bounds.midX - 18, y: bounds.midY - 18, width: 36, height: 36),
            contents: image
        )
        return drag
    }
}

/// Finder understands `.fileURL`; Terminal and older AppKit destinations may prefer a filename/path flavor.
/// Providing all representations from one writer avoids AppKit synthesizing a transient `/tmp/...` file path.
private final class FilePathDragWriter: NSObject, NSPasteboardWriting {
    private static let legacyFilenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    private let url: URL

    init(url: URL) {
        self.url = url
        super.init()
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [.fileURL, Self.legacyFilenamesType, .URL, .string]
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .fileURL, .URL:
            return url.absoluteString
        case .string:
            return url.path
        case Self.legacyFilenamesType:
            return [url.path]
        default:
            return nil
        }
    }
}
#endif

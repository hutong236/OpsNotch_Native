#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

/// Native AppKit drag source retained so we can observe the final NSDragOperation.
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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        ShelfRowDragHitCoordinator.shared.register(self)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        ShelfRowDragHitCoordinator.shared.register(self)
    }

    deinit {
        ShelfRowDragHitCoordinator.shared.unregister(self)
    }

    override func mouseDown(with event: NSEvent) {
        prepareForDrag(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        _ = startDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        let shouldClick = mouseDownEvent != nil && !didStartDrag
        resetPendingMouseState()
        if shouldClick { onClick?() }
    }

    /// SwiftUI contextMenu 仍挂在外层 row；handle 上右键时交回宿主 responder chain。
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

    /// The SwiftUI row currently gives this representable a compact visual handle. To avoid forcing users
    /// to target 16x18pt, one shared event bridge treats the primary row body (left of action buttons) as
    /// the same native drag source. Clicks still go through SwiftUI; only an actual mouse-drag is consumed.
    fileprivate var practicalRowDragRectInWindow: NSRect? {
        guard let window, let contentView = window.contentView else { return nil }
        let handleRect = convert(bounds, to: nil)
        let contentBounds = contentView.bounds
        let rowHeight: CGFloat = 42
        let leftInset: CGFloat = 14
        // Hover action buttons live immediately to the left of the handle. Keep a generous exclusion zone
        // so preview/pin/working-set actions remain easy to click while the rest of the row is draggable.
        let actionExclusion: CGFloat = 132
        let minX = contentBounds.minX + leftInset
        let maxX = max(minX, handleRect.minX - actionExclusion)
        guard maxX - minX >= 40 else { return nil }
        return NSRect(
            x: minX,
            y: handleRect.midY - rowHeight / 2,
            width: maxX - minX,
            height: rowHeight
        )
    }

    fileprivate func prepareForDrag(with event: NSEvent) {
        mouseDownEvent = event
        didStartDrag = false
    }

    @discardableResult
    fileprivate func startDrag(with event: NSEvent) -> Bool {
        guard mouseDownEvent != nil, !didStartDrag, !items.isEmpty else { return false }

        var sourceItems: [ShelfItem] = []
        var draggingItems: [NSDraggingItem] = []
        for item in items {
            guard let draggingItem = makeDraggingItem(item, event: event) else { continue }
            sourceItems.append(item)
            draggingItems.append(draggingItem)
        }
        guard !draggingItems.isEmpty else { return false }

        didStartDrag = true
        activeSessionItems = sourceItems
        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        mouseDownEvent = nil
        return true
    }

    fileprivate func resetPendingMouseState() {
        mouseDownEvent = nil
        didStartDrag = false
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
        resetPendingMouseState()
        DragOutLifecycleCoordinator.shared.draggingEnded(items: completedItems, operation: operation)
    }

    private func makeDraggingItem(_ item: ShelfItem, event: NSEvent) -> NSDraggingItem? {
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
        let point = convert(event.locationInWindow, from: nil)
        drag.setDraggingFrame(
            NSRect(x: point.x - 18, y: point.y - 18, width: 36, height: 36),
            contents: image
        )
        return drag
    }
}

/// One local monitor serves every visible row using weak references. It does not swallow clicks; it only
/// starts the native drag session once AppKit has already produced a leftMouseDragged event.
private final class ShelfRowDragHitCoordinator {
    static let shared = ShelfRowDragHitCoordinator()

    private let sources = NSHashTable<DragSourceNSView>.weakObjects()
    private var monitor: Any?
    private weak var pendingSource: DragSourceNSView?

    private init() {}

    func register(_ source: DragSourceNSView) {
        sources.add(source)
        installMonitorIfNeeded()
    }

    func unregister(_ source: DragSourceNSView) {
        sources.remove(source)
        if pendingSource === source { pendingSource = nil }
    }

    private func installMonitorIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self else { return event }
            switch event.type {
            case .leftMouseDown:
                let candidate = self.source(at: event)
                self.pendingSource = candidate
                candidate?.prepareForDrag(with: event)
                return event
            case .leftMouseDragged:
                guard let source = self.pendingSource else { return event }
                if source.startDrag(with: event) {
                    self.pendingSource = nil
                    return nil
                }
                return event
            case .leftMouseUp:
                self.pendingSource?.resetPendingMouseState()
                self.pendingSource = nil
                return event
            default:
                return event
            }
        }
    }

    private func source(at event: NSEvent) -> DragSourceNSView? {
        guard let window = event.window else { return nil }
        let point = event.locationInWindow
        return sources.allObjects.first { source in
            source.window === window && (source.practicalRowDragRectInWindow?.contains(point) ?? false)
        }
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
        if type == .fileURL || type == .URL {
            return url.absoluteString
        }
        if type == .string {
            return url.path
        }
        if type == Self.legacyFilenamesType {
            return [url.path]
        }
        return nil
    }
}
#endif

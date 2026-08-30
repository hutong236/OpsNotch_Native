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

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard mouseDownEvent != nil, !items.isEmpty else { return }
        let draggingItems = items.compactMap(makeDraggingItem)
        guard !draggingItems.isEmpty else { return }
        beginDraggingSession(with: draggingItems, event: event, source: self)
        mouseDownEvent = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "Drag")
        image?.draw(in: bounds.insetBy(dx: 2, dy: 2), from: .zero, operation: .sourceOver, fraction: 0.45)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
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
            image = NSImage(systemSymbolName: "link", accessibilityDescription: nil) ?? NSImage(size: NSSize(width: 24, height: 24))
        case .text, .action:
            writer = item.content as NSString
            image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil) ?? NSImage(size: NSSize(width: 24, height: 24))
        }
        let drag = NSDraggingItem(pasteboardWriter: writer)
        drag.setDraggingFrame(NSRect(x: bounds.midX - 16, y: bounds.midY - 16, width: 32, height: 32), contents: image)
        return drag
    }
}
#endif

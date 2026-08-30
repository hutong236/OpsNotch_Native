#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

/// 置顶悬浮放大预览窗:独立于 Shelf 面板,常驻显示文字或图片内容,
/// 用户切换到其他应用后仍悬浮在最上层,直到手动关闭。
@MainActor
final class FloatingPreviewController: NSObject {
    static let shared = FloatingPreviewController()
    static let fontSizes: [CGFloat] = [13, 16, 20, 26, 34, 44]

    enum Payload {
        case text(title: String, text: String)
        case image(title: String, url: URL)

        var title: String {
            switch self {
            case .text(let title, _), .image(let title, _): return title
            }
        }
    }

    private var panel: FloatingPreviewPanel?
    private var hostingView: NSHostingView<FloatingPreviewRoot>?

    func show(item: ShelfItem, language: AppLanguage) {
        let payload: Payload
        switch item.kind {
        case .text:
            payload = .text(title: item.title, text: item.content)
        case .file:
            guard FileManager.default.fileExists(atPath: item.content) else { return }
            payload = .image(title: item.title, url: URL(fileURLWithPath: item.content))
        case .folder, .url, .application, .action:
            return
        }

        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let screen else { return }
        let panel = ensurePanel()
        if !panel.isVisible { panel.setFrame(Self.defaultFrame(on: screen), display: true) }
        panel.contentView = hostingView(for: payload, language: language)
        panel.orderFrontRegardless()
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func ensurePanel() -> FloatingPreviewPanel {
        if let panel { return panel }
        let panel = FloatingPreviewPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        self.panel = panel
        return panel
    }

    private func hostingView(for payload: Payload, language: AppLanguage) -> NSHostingView<FloatingPreviewRoot> {
        let root = FloatingPreviewRoot(
            sessionID: UUID(),
            payload: payload,
            language: language,
            onClose: { [weak self] in self?.close() }
        )
        if let hostingView {
            hostingView.rootView = root
            return hostingView
        }
        let view = NSHostingView(rootView: root)
        view.autoresizingMask = [.width, .height]
        hostingView = view
        return view
    }

    private static func defaultFrame(on screen: NSScreen) -> NSRect {
        let size = NSSize(width: 480, height: 540)
        let sensorHeight = SensorGeometry.height(for: screen)
        // 出现在 Shelf 右侧,与面板错开;越界时收回屏幕内
        let x = min(max(screen.frame.midX + 240 - size.width / 2, screen.frame.minX + 12), screen.frame.maxX - size.width - 12)
        let y = max(screen.frame.maxY - sensorHeight - size.height - 12, screen.frame.minY + 12)
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}

final class FloatingPreviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct FloatingPreviewRoot: View {
    let sessionID: UUID
    let payload: FloatingPreviewController.Payload
    let language: AppLanguage
    let onClose: () -> Void

    @State private var fontIndex = 2
    @State private var fitToken = 0

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.35)
            content
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        .id(sessionID)
    }

    private var toolbar: some View {
        HStack(spacing: 9) {
            Image(systemName: toolbarIcon).font(.system(size: 12)).foregroundStyle(.secondary)
            Text(payload.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            if case .text = payload {
                Button {
                    if fontIndex > 0 { fontIndex -= 1 }
                } label: { Image(systemName: "minus").frame(width: 20, height: 20) }
                    .buttonStyle(.plain)
                    .disabled(fontIndex == 0)
                    .help(L10n.text("previewFont", language))
                Button {
                    if fontIndex < FloatingPreviewController.fontSizes.count - 1 { fontIndex += 1 }
                } label: { Image(systemName: "plus").frame(width: 20, height: 20) }
                    .buttonStyle(.plain)
                    .disabled(fontIndex == FloatingPreviewController.fontSizes.count - 1)
                    .help(L10n.text("previewFont", language))
            }
            if case .image = payload {
                Button {
                    fitToken += 1
                } label: { Image(systemName: "arrow.down.right.and.arrow.up.left").frame(width: 20, height: 20) }
                    .buttonStyle(.plain)
                    .help(L10n.text("previewFit", language))
            }
            Button {
                onClose()
            } label: { Image(systemName: "xmark").frame(width: 20, height: 20) }
                .buttonStyle(.plain)
                .help(L10n.text("previewClose", language))
        }
        .foregroundStyle(.secondary)
        .font(.system(size: 11))
        .padding(.horizontal, 12)
        .frame(height: 34)
    }

    private var toolbarIcon: String {
        switch payload {
        case .text: return "doc.text"
        case .image: return "photo"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch payload {
        case .text(_, let text):
            SelectableTextView(text: text, fontSize: FloatingPreviewController.fontSizes[fontIndex])
        case .image(_, let url):
            ZoomableImageContainer(url: url, resetToken: fitToken)
        }
    }
}

/// 可选中、可复制、自动换行、可滚动的文字预览区。
/// SwiftUI 的 Text 不可选中,这里包一层 NSScrollView + NSTextView。
private struct SelectableTextView: NSViewRepresentable {
    let text: String
    let fontSize: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isRichText = false
        textView.allowsUndo = false
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 4, height: 12)
        textView.backgroundColor = .clear
        scrollView.documentView = textView
        Self.apply(text: text, fontSize: fontSize, to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text || textView.font?.pointSize != fontSize {
            Self.apply(text: text, fontSize: fontSize, to: textView)
        }
    }

    private static func apply(text: String, fontSize: CGFloat, to textView: NSTextView) {
        let selection = textView.selectedRange()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = fontSize * 0.32
        paragraph.paragraphSpacing = fontSize * 0.4
        textView.textStorage?.setAttributedString(NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
        ))
        textView.selectedRange = NSRange(location: min(selection.location, (text as NSString).length), length: 0)
    }
}

/// 缩放平移图片容器:捏合/滚轮缩放,拖动平移,可一键复位。
private struct ZoomableImageContainer: NSViewRepresentable {
    let url: URL
    let resetToken: Int

    func makeNSView(context: Context) -> ZoomableImageView {
        let view = ZoomableImageView()
        context.coordinator.load(url: url, into: view)
        return view
    }

    func updateNSView(_ view: ZoomableImageView, context: Context) {
        context.coordinator.loadIfChanged(url: url, into: view)
        if context.coordinator.lastResetToken != resetToken {
            context.coordinator.lastResetToken = resetToken
            view.resetView()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        private var loadedURL: URL?
        var lastResetToken = 0

        func loadIfChanged(url: URL, into view: ZoomableImageView) {
            guard url != loadedURL else { return }
            load(url: url, into: view)
        }

        func load(url: URL, into view: ZoomableImageView) {
            loadedURL = url
            let target = view
            Task.detached(priority: .userInitiated) {
                let image = NSImage(contentsOf: url)
                await MainActor.run {
                    guard target.window != nil || target.superview != nil else { return }
                    target.setImage(image)
                }
            }
        }
    }
}

private final class ZoomableImageView: NSView {
    private var image: NSImage?
    private var scale: CGFloat = 1
    private var translation: CGPoint = .zero
    private var dragAnchor: CGPoint?
    private var fitSize: CGSize = .zero

    func setImage(_ image: NSImage?) {
        self.image = image
        scale = 1
        translation = .zero
        needsDisplay = true
    }

    func resetView() {
        scale = 1
        translation = .zero
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 1, bounds.height > 1 else { return }
        guard let image, image.size.width > 0, image.size.height > 0 else { return }
        let ratio = min(bounds.width / image.size.width, bounds.height / image.size.height)
        fitSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let rect = CGRect(
            x: bounds.midX + translation.x - fitSize.width * scale / 2,
            y: bounds.midY + translation.y - fitSize.height * scale / 2,
            width: fitSize.width * scale,
            height: fitSize.height * scale
        )
        image.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high.rawValue]
        )
    }

    override func magnify(with event: NSEvent) {
        applyZoom(multiplier: 1 + event.magnification, anchor: convert(event.locationInWindow, from: nil))
    }

    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaY) > 0.01 {
            applyZoom(multiplier: 1 - event.scrollingDeltaY * 0.002, anchor: convert(event.locationInWindow, from: nil))
        } else if abs(event.scrollingDeltaX) > 0.01, scale > 1 {
            translation.x -= event.scrollingDeltaX
            clampTranslation()
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        dragAnchor = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if scale > 1, let anchor = dragAnchor {
            translation.x += location.x - anchor.x
            translation.y += location.y - anchor.y
            dragAnchor = location
            clampTranslation()
            needsDisplay = true
        } else if scale == 1 {
            // 未放大时拖动整个预览窗,方便用户挪到参照位置
            window?.performDrag(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        dragAnchor = nil
    }

    private func applyZoom(multiplier: CGFloat, anchor: CGPoint) {
        let newScale = min(max(scale * multiplier, 1), 16)
        guard newScale != scale else { return }
        let ratio = newScale / scale
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        translation = CGPoint(
            x: (anchor.x - center.x) * (1 - ratio) + translation.x * ratio,
            y: (anchor.y - center.y) * (1 - ratio) + translation.y * ratio
        )
        scale = newScale
        if scale == 1 { translation = .zero }
        clampTranslation()
        needsDisplay = true
    }

    private func clampTranslation() {
        guard fitSize.width > 0, fitSize.height > 0, bounds.width > 0, bounds.height > 0 else { return }
        let maxX = max((fitSize.width * scale - bounds.width) / 2, 0)
        let maxY = max((fitSize.height * scale - bounds.height) / 2, 0)
        translation.x = min(max(translation.x, -maxX), maxX)
        translation.y = min(max(translation.y, -maxY), maxY)
    }
}
#endif

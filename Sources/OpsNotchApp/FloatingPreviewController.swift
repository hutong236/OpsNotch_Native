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
    static let defaultFontSize: CGFloat = fontSizes[2]

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
    private var currentLanguage: AppLanguage = .zhCN
    private var currentPayload: Payload?

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
        currentPayload = payload
        currentLanguage = language

        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let screen else { return }
        let panel = ensurePanel()
        panel.contentView = hostingView(for: payload, language: language)

        // 每开一个新条目都自适应窗口尺寸:文字按字数/行数估计,图片取实际像素
        let frame = Self.adaptiveFrame(for: payload, on: screen, existing: panel.frame, wasVisible: panel.isVisible)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    func close() {
        panel?.orderOut(nil)
        currentPayload = nil
    }

    /// 字号变化后按当前内容重新估计窗口尺寸(保持面板原锚点右上)。
    fileprivate func fontDidChange(_ size: CGFloat) {
        guard let payload = currentPayload, let panel, panel.isVisible else { return }
        guard let screen = NSScreen.screens.first(where: { NSIntersectsRect($0.frame, panel.frame) }) ?? NSScreen.main else { return }
        let fitted = Self.adaptiveFrame(for: payload, on: screen, fontSize: size, existing: panel.frame, wasVisible: true)
        panel.setFrame(fitted, display: true, animate: true)
    }

    /// 图片实际像素加载完成后回调,按像素重调窗口。
    fileprivate func imageDidLoad(_ pixelSize: CGSize) {
        guard case .image(let title, let url) = currentPayload, let panel, panel.isVisible else { return }
        guard let screen = NSScreen.screens.first(where: { NSIntersectsRect($0.frame, panel.frame) }) ?? NSScreen.main else { return }
        let fitted = Self.adaptiveFrame(for: .image(title: title, url: url), on: screen, pixelSize: pixelSize, existing: panel.frame, wasVisible: true)
        panel.setFrame(fitted, display: true, animate: true)
    }

    private func ensurePanel() -> FloatingPreviewPanel {
        if let panel { return panel }
        let panel = FloatingPreviewPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
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
        panel.minSize = NSSize(width: 280, height: 180)
        self.panel = panel
        return panel
    }

    private func hostingView(for payload: Payload, language: AppLanguage) -> NSHostingView<FloatingPreviewRoot> {
        let root = FloatingPreviewRoot(
            sessionID: UUID(),
            payload: payload,
            language: language,
            onClose: { [weak self] in self?.close() },
            onFontChange: { [weak self] size in self?.fontDidChange(size) },
            onImageLoad: { [weak self] size in self?.imageDidLoad(size) }
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

    /// 窗口自适应:文字按内容估行列,图片按像素比例,都夹在屏幕可用区域内。
    /// 已打开过的窗口默认保持当前尺寸不变(用户拖过就不动),只有首次出现或内容换时才重估。
    private static func adaptiveFrame(
        for payload: Payload,
        on screen: NSScreen,
        fontSize: CGFloat? = nil,
        pixelSize: CGSize? = nil,
        existing: NSRect,
        wasVisible: Bool
    ) -> NSRect {
        let usable = screen.visibleFrame
        let maxW = min(usable.width - 40, 780)
        let maxH = min(usable.height - 40, 660)
        let minW: CGFloat = 300, minH: CGFloat = 200

        let contentSize: CGSize
        switch payload {
        case .text(_, let text):
            contentSize = estimateTextSize(text: text, fontSize: fontSize ?? Self.defaultFontSize, maxW: maxW - 40, maxH: maxH - 60)
        case .image(_, let url):
            let px = pixelSize ?? Self.imagePixelSize(url: url) ?? CGSize(width: 480, height: 400)
            contentSize = fitImage(pixel: px, maxW: maxW - 40, maxH: maxH - 60)
        }

        let w = min(max(contentSize.width + 40, minW), maxW)
        let h = min(max(contentSize.height + 60, minH), maxH)

        let x: CGFloat
        let y: CGFloat
        if wasVisible {
            // 已开着的窗口:保持左上,宽度/高度变化时向左侧扩展,避免盖住 Shelf
            x = min(max(existing.minX, usable.minX + 8), usable.maxX - w - 8)
            y = min(max(existing.maxY - h, usable.minY + 8), usable.maxY - h - 8)
        } else {
            // 首次出现:放屏幕中上部,避开刘海正下方
            x = usable.midX - w / 2
            y = usable.maxY - SensorGeometry.height(for: screen) - h - 24
        }
        return NSRect(x: x, y: y, width: w, height: h)
    }

    private static func estimateTextSize(text: String, fontSize: CGFloat, maxW: CGFloat, maxH: CGFloat) -> CGSize {
        // 按最长行字数估计宽度,行数×行高估计高度;中文字宽按字号 1:1,英文按 0.6
        let lines = text.components(separatedBy: "\n")
        let charWidth = fontSize * 1.0
        let maxChars = lines.map { line -> Int in
            line.reduce(0) { count, ch in count + (ch.unicodeScalars.first.map { $0.value > 0x2E80 } == true ? 1 : 0) + 0 }
        }.max() ?? 10
        let ascii = lines.map { line -> Int in
            line.reduce(0) { count, ch in count + (ch.unicodeScalars.first.map { $0.value > 0x2E80 } == true ? 0 : 1) }
        }.max() ?? 0
        let estimatedW = min(CGFloat(maxChars) * charWidth + CGFloat(ascii) * fontSize * 0.62, maxW)
        let lineCount = max(lines.count, 1)
        let lineHeight = fontSize * 1.72
        let estimatedH = min(CGFloat(lineCount) * lineHeight + 32, maxH)
        return CGSize(width: max(estimatedW, 260), height: max(estimatedH, 120))
    }

    private static func fitImage(pixel: CGSize, maxW: CGFloat, maxH: CGFloat) -> CGSize {
        guard pixel.width > 0, pixel.height > 0 else { return CGSize(width: 420, height: 320) }
        let scale = min(maxW / pixel.width, maxH / pixel.height, 1)
        return CGSize(width: pixel.width * scale, height: pixel.height * scale)
    }

    private static func imagePixelSize(url: URL) -> CGSize? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let h = props[kCGImagePropertyPixelHeight] as? CGFloat else { return nil }
        return CGSize(width: w, height: h)
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
    let onFontChange: (CGFloat) -> Void
    let onImageLoad: (CGSize) -> Void

    @State private var fontIndex = 2
    @State private var fitToken = 0
    @State private var zoomRequest = ImageZoomRequest()

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
                    if fontIndex > 0 { fontIndex -= 1; onFontChange(FloatingPreviewController.fontSizes[fontIndex]) }
                } label: { Image(systemName: "minus").frame(width: 20, height: 20) }
                    .buttonStyle(.plain)
                    .disabled(fontIndex == 0)
                    .help(L10n.text("previewFont", language))
                Text("\(Int(FloatingPreviewController.fontSizes[fontIndex]))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Button {
                    if fontIndex < FloatingPreviewController.fontSizes.count - 1 { fontIndex += 1; onFontChange(FloatingPreviewController.fontSizes[fontIndex]) }
                } label: { Image(systemName: "plus").frame(width: 20, height: 20) }
                    .buttonStyle(.plain)
                    .disabled(fontIndex == FloatingPreviewController.fontSizes.count - 1)
                    .help(L10n.text("previewFont", language))
            }
            if case .image = payload {
                Button {
                    zoomRequest = ImageZoomRequest(token: zoomRequest.token &+ 1, factor: 0.8)
                } label: { Image(systemName: "minus.magnifyingglass").frame(width: 20, height: 20) }
                    .buttonStyle(.plain)
                    .help(L10n.text("previewZoomOut", language))
                Button {
                    zoomRequest = ImageZoomRequest(token: zoomRequest.token &+ 1, factor: 1.25)
                } label: { Image(systemName: "plus.magnifyingglass").frame(width: 20, height: 20) }
                    .buttonStyle(.plain)
                    .help(L10n.text("previewZoomIn", language))
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
            ZoomableImageContainer(url: url, resetToken: fitToken, zoomRequest: zoomRequest, onLoad: onImageLoad)
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
        textView.textContainerInset = NSSize(width: 8, height: 14)
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

/// 图片缩放指令:工具条 +/− 按钮通过 token 变化下发到 NSView。
private struct ImageZoomRequest: Equatable {
    var token: Int = 0
    var factor: CGFloat = 1
}

/// 缩放平移图片容器:捏合/滚轮缩放,拖动平移,可一键复位。
private struct ZoomableImageContainer: NSViewRepresentable {
    let url: URL
    let resetToken: Int
    let zoomRequest: ImageZoomRequest
    let onLoad: (CGSize) -> Void

    func makeNSView(context: Context) -> ZoomableImageView {
        let view = ZoomableImageView()
        context.coordinator.onLoad = onLoad
        context.coordinator.load(url: url, into: view)
        return view
    }

    func updateNSView(_ view: ZoomableImageView, context: Context) {
        context.coordinator.onLoad = onLoad
        context.coordinator.loadIfChanged(url: url, into: view)
        if context.coordinator.lastResetToken != resetToken {
            context.coordinator.lastResetToken = resetToken
            view.resetView()
        }
        if context.coordinator.lastZoomToken != zoomRequest.token {
            context.coordinator.lastZoomToken = zoomRequest.token
            view.applyZoomFactor(zoomRequest.factor)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        private var loadedURL: URL?
        var lastResetToken = 0
        var lastZoomToken = 0
        var onLoad: ((CGSize) -> Void)?

        func loadIfChanged(url: URL, into view: ZoomableImageView) {
            guard url != loadedURL else { return }
            load(url: url, into: view)
        }

        func load(url: URL, into view: ZoomableImageView) {
            loadedURL = url
            let target = view
            Task.detached(priority: .userInitiated) {
                let image = NSImage(contentsOf: url)
                let pixelSize = image.flatMap { img -> CGSize? in
                    img.representations.first.map { CGSize(width: CGFloat($0.pixelsWide), height: CGFloat($0.pixelsHigh)) }
                }
                await MainActor.run {
                    guard target.window != nil || target.superview != nil else { return }
                    target.setImage(image)
                    if let pixelSize { self.onLoad?(pixelSize) }
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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // 刻意不开 wantsLayer:layer 内容不会裁剪到视图边界,图片放大后会把
        // 上方 SwiftUI 绘制的工具条/关闭按钮整个盖住;非 layer 视图 draw 自动裁剪。
    }

    required init?(coder: NSCoder) { nil }

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

    func applyZoomFactor(_ factor: CGFloat) {
        applyZoom(multiplier: factor, anchor: CGPoint(x: bounds.midX, y: bounds.midY))
    }

    /// 关键:面板 isMovableByWindowBackground = true 时,非不透明视图默认
    /// mouseDownCanMoveWindow == true,拖动会被系统直接拿去移窗、视图收不到
    /// mouseDragged(表现为图片无法平移)。这里声明拖动由本视图自己处理。
    override var mouseDownCanMoveWindow: Bool { false }

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
        // 惯性阶段(momentum)不参与缩放,否则松手后还会持续缩很久
        guard event.momentumPhase == .none else { return }
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

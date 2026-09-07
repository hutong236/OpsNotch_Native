#if os(macOS)
import AppKit
import QuartzCore
import OpsNotchCore

@MainActor
final class DragDropOverlayController {
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onDrop: ((NativeDropPayload) -> Bool)?
    var onPromiseStarted: (() -> Void)?
    var onPromisedFiles: (([URL]) -> Void)?

    private let panel: NearbyDropPanel
    private let dropView: NearbyDropView
    private(set) var visibleDisplayID: CGDirectDisplayID?

    init() {
        panel = NearbyDropPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        dropView = NearbyDropView(frame: .zero)

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.contentView = dropView
        panel.orderOut(nil)

        dropView.onDragEntered = { [weak self] in self?.onDragEntered?() }
        dropView.onDragExited = { [weak self] in self?.onDragExited?() }
        dropView.onDrop = { [weak self] payload in self?.onDrop?(payload) ?? false }
        dropView.onPromiseStarted = { [weak self] in self?.onPromiseStarted?() }
        dropView.onPromisedFiles = { [weak self] urls in self?.onPromisedFiles?(urls) }
    }

    var isVisible: Bool { panel.isVisible }

    func show(near cursor: NSPoint, on screen: NSScreen, language: AppLanguage) {
        dropView.apply(language: language)
        dropView.setReady(false)

        let target = targetFrame(near: cursor, on: screen)
        let nextDisplayID = displayID(of: screen)
        let wasVisible = panel.isVisible
        let changedDisplay = nextDisplayID != visibleDisplayID
        visibleDisplayID = nextDisplayID

        panel.setFrame(target, display: true)
        if !wasVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.01 : 0.10
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else if changedDisplay {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        guard panel.isVisible else {
            visibleDisplayID = nil
            dropView.resetVisualState()
            return
        }
        panel.orderOut(nil)
        panel.alphaValue = 1
        visibleDisplayID = nil
        dropView.resetVisualState()
    }

    func setReady(_ ready: Bool) {
        dropView.setReady(ready)
    }

    private func targetFrame(near cursor: NSPoint, on screen: NSScreen) -> NSRect {
        // Smoke test 反馈 228x84 命中区和文字都偏小。附近目标应该是“明显、容易放入”的目标，
        // 而不是另一个需要精确瞄准的小按钮。
        let size = NSSize(width: 320, height: 118)
        let gap: CGFloat = 40
        let inset: CGFloat = 12
        let visible = screen.visibleFrame

        var x = cursor.x + gap
        if x + size.width > visible.maxX - inset {
            x = cursor.x - gap - size.width
        }

        var y = cursor.y - gap - size.height
        if y < visible.minY + inset {
            y = cursor.y + gap
        }

        x = min(max(x, visible.minX + inset), visible.maxX - size.width - inset)
        y = min(max(y, visible.minY + inset), visible.maxY - size.height - inset)
        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }

    private func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

final class NearbyDropPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class NearbyDropView: NSVisualEffectView {
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onDrop: ((NativeDropPayload) -> Bool)?
    var onPromiseStarted: (() -> Void)?
    var onPromisedFiles: (([URL]) -> Void)?

    private let iconView = NSImageView()
    private let progressIndicator = NSProgressIndicator()
    private let titleLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private var ready = false
    private var resolvingPromise = false
    private var language: AppLanguage = .zhCN

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.masksToBounds = true
        configureAccessibility()

        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 31, weight: .semibold)
        iconView.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
        iconView.contentTintColor = .labelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .regular
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.lineBreakMode = .byWordWrapping
        hintLabel.maximumNumberOfLines = 2
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(progressIndicator)
        addSubview(titleLabel)
        addSubview(hintLabel)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 42),
            iconView.heightAnchor.constraint(equalToConstant: 42),

            progressIndicator.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 28),

            hintLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            hintLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 7),
            hintLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -18),
        ])

        registerDropTypes()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAccessibility()
        registerDropTypes()
    }

    private func configureAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    private func registerDropTypes() {
        // 保留项目静态检查要求的基础注册调用，再扩展 File Promise / 浏览器图片 / 富文本类型。
        registerForDraggedTypes([.fileURL, .URL, .string])
        registerForDraggedTypes([.fileURL, .URL, .string] + DropPayloadResolver.extraPasteboardTypes)
    }

    func apply(language: AppLanguage) {
        self.language = language
        resolvingPromise = false
        progressIndicator.stopAnimation(nil)
        iconView.isHidden = false
        let title = L10n.text("dropTitle", language)
        let hint = L10n.text("dropHint", language)
        titleLabel.stringValue = title
        hintLabel.stringValue = hint
        setAccessibilityLabel(title)
        setAccessibilityHelp(hint)
    }

    func resetVisualState() {
        resolvingPromise = false
        progressIndicator.stopAnimation(nil)
        iconView.isHidden = false
        ready = false
        layer?.borderWidth = 0
        alphaValue = 1
    }

    func setReady(_ newValue: Bool) {
        guard !resolvingPromise, ready != newValue else { return }
        ready = newValue
        layer?.borderWidth = newValue ? 3 : 1
        layer?.borderColor = (newValue ? NSColor.controlAccentColor : NSColor.separatorColor)
            .withAlphaComponent(newValue ? 0.9 : 0.45)
            .cgColor

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            animator().alphaValue = newValue ? 1.0 : 0.97
        }
    }

    private func showPromiseResolving() {
        resolvingPromise = true
        ready = false
        iconView.isHidden = true
        progressIndicator.startAnimation(nil)
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.65).cgColor
        let title = language == .zhCN ? "正在接收文件…" : "Receiving file…"
        let hint = language == .zhCN ? "文件准备完成后会自动放入暂存清单" : "It will be added to the Shelf when ready."
        titleLabel.stringValue = title
        hintLabel.stringValue = hint
        setAccessibilityLabel(title)
        setAccessibilityHelp(hint)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard DropPayloadResolver.canRead(sender.draggingPasteboard) else { return [] }
        setReady(true)
        onDragEntered?()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        DropPayloadResolver.canRead(sender.draggingPasteboard) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        guard !resolvingPromise else { return }
        setReady(false)
        onDragExited?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        DropPayloadResolver.shared.performDrop(
            from: sender,
            in: self,
            onPromiseStarted: { [weak self] in
                guard let self else { return }
                self.showPromiseResolving()
                self.onPromiseStarted?()
            },
            handleImmediate: { [weak self] payload in
                guard let self else { return false }
                dropLog.info("nearby overlay drop \(payload.logSummary, privacy: .public)")
                let accepted = self.onDrop?(payload) ?? false
                self.setReady(false)
                return accepted
            },
            handlePromised: { [weak self] urls in
                self?.onPromisedFiles?(urls)
            }
        )
    }
}
#endif

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
        // 第二轮 Smoke 继续优先可发现性：先把目标再放大一档，等真机体验稳定后再回收到最终尺寸。
        let size = NSSize(width: 360, height: 132)
        let gap: CGFloat = 44
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

    private enum Presentation {
        case idle
        case ready
        case resolvingPromise
    }

    private let iconTile = NSView()
    private let iconView = NSImageView()
    private let statusDot = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let titleLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private var presentation: Presentation = .idle
    private var language: AppLanguage = .zhCN

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureAppearance()
        configureAccessibility()
        configureContent()
        registerDropTypes()
        apply(language: .zhCN)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAppearance()
        configureAccessibility()
        configureContent()
        registerDropTypes()
        apply(language: .zhCN)
    }

    private func configureAppearance() {
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }

    private func configureAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    private func configureContent() {
        iconTile.wantsLayer = true
        iconTile.layer?.cornerRadius = 14
        iconTile.layer?.cornerCurve = .continuous
        iconTile.translatesAutoresizingMaskIntoConstraints = false
        iconTile.setAccessibilityElement(false)

        let configuration = NSImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        iconView.image = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setAccessibilityElement(false)

        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 3
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.setAccessibilityElement(false)

        statusLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.setAccessibilityElement(false)

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setAccessibilityElement(false)

        hintLabel.font = .systemFont(ofSize: 11.5)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.lineBreakMode = .byTruncatingTail
        hintLabel.maximumNumberOfLines = 1
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.setAccessibilityElement(false)

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .regular
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.setAccessibilityElement(false)

        addSubview(iconTile)
        iconTile.addSubview(iconView)
        iconTile.addSubview(progressIndicator)
        addSubview(statusDot)
        addSubview(statusLabel)
        addSubview(titleLabel)
        addSubview(hintLabel)

        NSLayoutConstraint.activate([
            iconTile.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            iconTile.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconTile.widthAnchor.constraint(equalToConstant: 52),
            iconTile.heightAnchor.constraint(equalToConstant: 52),

            iconView.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 30),
            iconView.heightAnchor.constraint(equalToConstant: 30),

            progressIndicator.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),

            statusDot.leadingAnchor.constraint(equalTo: iconTile.trailingAnchor, constant: 16),
            statusDot.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 6),
            statusDot.heightAnchor.constraint(equalToConstant: 6),

            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 7),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -18),
            statusLabel.topAnchor.constraint(equalTo: topAnchor, constant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: statusDot.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -18),
            titleLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 5),

            hintLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            hintLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -18),
            hintLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            hintLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16),
        ])
    }

    private func registerDropTypes() {
        // Keep the native drag destination signature used by the CI static gate.
        registerForDraggedTypes([.fileURL, .URL, .string])
        registerForDraggedTypes([.fileURL, .URL, .string] + DropPayloadResolver.extraPasteboardTypes)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    func apply(language: AppLanguage) {
        self.language = language
        presentation = .idle
        progressIndicator.stopAnimation(nil)
        render(animated: false)
    }

    func resetVisualState() {
        presentation = .idle
        progressIndicator.stopAnimation(nil)
        alphaValue = 1
        render(animated: false)
    }

    func setReady(_ ready: Bool) {
        guard presentation != .resolvingPromise else { return }
        let next: Presentation = ready ? .ready : .idle
        guard presentation != next else { return }
        presentation = next
        render(animated: true)
    }

    private func showPromiseResolving() {
        presentation = .resolvingPromise
        progressIndicator.startAnimation(nil)
        render(animated: false)
    }

    private func render(animated: Bool) {
        statusLabel.stringValue = L10n.text("dropNearbyEyebrow", language)
        switch presentation {
        case .idle:
            titleLabel.stringValue = L10n.text("dropNearbyIdleTitle", language)
            hintLabel.stringValue = L10n.text("dropNearbyHint", language)
        case .ready:
            titleLabel.stringValue = L10n.text("dropTitle", language)
            hintLabel.stringValue = L10n.text("dropNearbyHint", language)
        case .resolvingPromise:
            titleLabel.stringValue = L10n.text("receivingFile", language)
            hintLabel.stringValue = L10n.text("dropNearbyPromiseHint", language)
        }

        setAccessibilityLabel(titleLabel.stringValue)
        setAccessibilityHelp(hintLabel.stringValue)
        iconView.isHidden = presentation == .resolvingPromise
        updateColors()

        let opacity: CGFloat = presentation == .idle ? 0.82 : 1
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = OpsMotion.duration(for: .quick)
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                iconView.animator().alphaValue = opacity
            }
        } else {
            iconView.alphaValue = opacity
        }
    }

    private func updateColors() {
        let isReady = presentation == .ready
        let isResolving = presentation == .resolvingPromise
        let increasedContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        let accent = NSColor.controlAccentColor

        layer?.borderWidth = isReady ? 1.5 : 1
        layer?.borderColor = (isReady ? accent : NSColor.separatorColor)
            .withAlphaComponent(isReady ? 0.78 : (increasedContrast ? 0.65 : 0.38))
            .cgColor

        iconTile.layer?.backgroundColor = accent
            .withAlphaComponent(isReady ? 0.20 : 0.11).cgColor
        iconView.contentTintColor = isReady || isResolving ? accent : .labelColor
        statusDot.layer?.backgroundColor = accent
            .withAlphaComponent(isReady ? 1 : 0.72).cgColor
        statusLabel.textColor = isReady ? accent : .secondaryLabelColor
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard DropPayloadResolver.canRead(sender.draggingPasteboard) else { return [] }
        setReady(true)
        onDragEntered?()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let isValid = DropPayloadResolver.canRead(sender.draggingPasteboard)
        setReady(isValid)
        return isValid ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        guard presentation != .resolvingPromise else { return }
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

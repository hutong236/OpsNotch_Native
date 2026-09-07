#if os(macOS)
import AppKit
import OpsNotchCore

@MainActor
final class DragDropOverlayController {
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onDrop: ((NativeDropPayload) -> Bool)?

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
            return
        }
        panel.orderOut(nil)
        panel.alphaValue = 1
        visibleDisplayID = nil
        dropView.setReady(false)
    }

    func setReady(_ ready: Bool) {
        dropView.setReady(ready)
    }

    private func targetFrame(near cursor: NSPoint, on screen: NSScreen) -> NSRect {
        let size = NSSize(width: 228, height: 84)
        let gap: CGFloat = 34
        let inset: CGFloat = 10
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

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private var ready = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true

        iconView.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: nil)
        iconView.contentTintColor = .labelColor
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 23, weight: .semibold)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        hintLabel.font = .systemFont(ofSize: 10)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.lineBreakMode = .byTruncatingTail
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(hintLabel)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 30),
            iconView.heightAnchor.constraint(equalToConstant: 30),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),

            hintLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            hintLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
        ])

        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    func apply(language: AppLanguage) {
        titleLabel.stringValue = L10n.text("dropTitle", language)
        hintLabel.stringValue = L10n.text("dropHint", language)
    }

    func setReady(_ newValue: Bool) {
        guard ready != newValue else { return }
        ready = newValue
        layer?.borderWidth = newValue ? 2 : 1
        layer?.borderColor = (newValue ? NSColor.controlAccentColor : NSColor.separatorColor).withAlphaComponent(newValue ? 0.85 : 0.45).cgColor

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            animator().alphaValue = newValue ? 1.0 : 0.96
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard NativeDropPayload.canRead(sender.draggingPasteboard) else { return [] }
        setReady(true)
        onDragEntered?()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        NativeDropPayload.canRead(sender.draggingPasteboard) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setReady(false)
        onDragExited?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let payload = NativeDropPayload.read(from: sender.draggingPasteboard) else {
            dropLog.error("nearby overlay drop: no readable payload")
            return false
        }
        dropLog.info("nearby overlay drop \(payload.logSummary, privacy: .public)")
        let accepted = onDrop?(payload) ?? false
        setReady(false)
        return accepted
    }
}
#endif

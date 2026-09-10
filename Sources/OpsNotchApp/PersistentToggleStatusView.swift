#if os(macOS)

import AppKit

/// Custom status item view that keeps the hidden-area toggle anchored
/// on the visible Ops Notch side while the hidden spacer changes size.
@MainActor
final class PersistentToggleStatusView: NSView {
    var onToggle: (() -> Void)?

    private let toggleButton: NSButton

    var symbol: String = "‹" {
        didSet {
            toggleButton.title = symbol
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 17, height: 22)
    }

    override init(frame frameRect: NSRect) {
        toggleButton = NSButton(title: "‹", target: nil, action: nil)
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        wantsLayer = true

        toggleButton.isBordered = false
        toggleButton.font = .systemFont(ofSize: 13, weight: .regular)
        toggleButton.alignment = .center
        toggleButton.target = self
        toggleButton.action = #selector(togglePressed)
        toggleButton.sendAction(on: [.leftMouseUp])

        addSubview(toggleButton)
    }

    override func layout() {
        super.layout()
        toggleButton.frame = NSRect(
            x: bounds.width - 17,
            y: 0,
            width: 17,
            height: bounds.height
        )
    }

    @objc
    private func togglePressed() {
        onToggle?()
    }
}

#endif

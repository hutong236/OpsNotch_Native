#if os(macOS)
import AppKit
import ImageIO
import SwiftUI
import OpsNotchCore

/// A source-neutral row. System interactions and selection are supplied by the host.
struct ShelfRow: View {
    let item: ShelfPresentationItem
    let visualState: OpsRowVisualState
    let onPrimaryAction: () -> Void
    let onSecondaryAction: (ShelfPresentationItem.Action) -> Void
    var additionalActionsLabel: String
    var dragItems: [ShelfItem] = []
    var dragLabel: String = ""
    @State private var hovered = false
    @State private var resource: NSImage?

    private var resourceKey: String {
        if case .imageFile(let path) = item.thumbnail { return "image:\(path)" }
        if case .file(let path, _) = item.icon { return "icon:\(path)" }
        return ""
    }

    var body: some View {
        Button(action: onPrimaryAction) {
            HStack(spacing: OpsSpacing.small) {
                if visualState.selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                }
                icon.frame(width: OpsSpacing.xxLarge, height: OpsSpacing.xxLarge)
                VStack(alignment: .leading, spacing: OpsSpacing.micro) {
                    HStack(spacing: OpsSpacing.xSmall) {
                        Text(item.title).font(OpsTypography.rowTitle).lineLimit(1)
                        if let badge = item.badge { ShelfBadge(text: badge) }
                    }
                    Text(item.subtitle).font(OpsTypography.shelfSubtitle).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    if !item.metadata.isEmpty {
                        Text(item.metadata.joined(separator: " · ")).font(OpsTypography.metadata)
                            .foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: OpsSpacing.xSmall)
            }
            .padding(.leading, OpsSpacing.small)
            .padding(.trailing, trailingSpace)
            .frame(maxWidth: .infinity, minHeight: OpsControlMetrics.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(ShelfRowButtonStyle(state: resolvedVisualState))
        .accessibilityLabel(Text(item.accessibilityLabel))
        .accessibilityHint(Text(item.accessibilityHint))
        .overlay(alignment: .trailing) { accessories.padding(.trailing, OpsSpacing.xSmall) }
        .contextMenu { actionMenu }
        .disabled(visualState.disabled)
        .onHover { hovered = $0 }
        .task(id: resourceKey) { resource = ShelfRowImageCache.shared.image(for: item) }
    }

    private var resolvedVisualState: OpsRowVisualState {
        OpsRowVisualState(
            selected: visualState.selected,
            focused: visualState.focused,
            hovered: visualState.hovered || hovered,
            disabled: visualState.disabled,
            dragging: visualState.dragging
        )
    }

    private var trailingSpace: CGFloat {
        OpsControlMetrics.minimumHitTarget * 2 + (dragItems.isEmpty ? OpsSpacing.small : OpsControlMetrics.minimumHitTarget) + OpsSpacing.small
    }

    @ViewBuilder private var icon: some View {
        if let resource {
            Image(nsImage: resource).resizable().aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: OpsRadius.control))
        } else {
            switch item.icon {
            case .symbol(let name), .file(_, let name):
                Image(systemName: name).font(OpsTypography.title).foregroundStyle(.secondary)
            }
        }
    }

    private var accessories: some View {
        HStack(spacing: OpsSpacing.micro) {
            if resolvedVisualState.showsAccessories {
                if let first = item.secondaryActions.first {
                    OpsIconButton(systemName: first.symbolName, accessibilityLabel: first.title) { onSecondaryAction(first) }
                }
                if !item.secondaryActions.isEmpty {
                    Menu { actionMenu } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: OpsControlMetrics.minimumHitTarget, height: OpsControlMetrics.minimumHitTarget)
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden)
                    .accessibilityLabel(Text(additionalActionsLabel)).help(additionalActionsLabel)
                }
            }
            if !dragItems.isEmpty {
                NativeDragSourceView(items: dragItems)
                    .frame(width: OpsControlMetrics.minimumHitTarget, height: OpsControlMetrics.minimumHitTarget)
                    .help(dragLabel).accessibilityLabel(Text(dragLabel))
            }
        }
    }

    @ViewBuilder private var actionMenu: some View {
        Button(item.primaryAction.title, action: onPrimaryAction)
        ForEach(Array(item.secondaryActions.enumerated()), id: \.offset) { _, action in
            Button(role: isDestructive(action) ? .destructive : nil) { onSecondaryAction(action) } label: {
                Label(action.title, systemImage: action.symbolName)
            }
        }
    }

    private func isDestructive(_ action: ShelfPresentationItem.Action) -> Bool {
        if case .removeShelfItem = action.intent { return true }
        return false
    }
}

private struct ShelfBadge: View {
    let text: String
    var body: some View {
        Text(text).font(OpsTypography.micro).foregroundStyle(.secondary)
            .padding(.horizontal, OpsSpacing.xSmall).padding(.vertical, OpsSpacing.micro)
            .background(OpsSurface.hover, in: Capsule())
    }
}

private struct ShelfRowButtonStyle: ButtonStyle {
    let state: OpsRowVisualState
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                background(pressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: OpsRadius.shelfRow)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OpsRadius.shelfRow)
                    .strokeBorder(
                        state.showsFocusRing
                            ? OpsSurface.focusStroke(increasedContrast: increasedContrast)
                            : .clear,
                        lineWidth: increasedContrast ? 1.5 : 1
                    )
            )
            .opacity(isEnabled ? 1 : 0.45)
    }

    private var increasedContrast: Bool { colorSchemeContrast == .increased }

    private func background(pressed: Bool) -> Color {
        if pressed { return OpsSurface.focused }
        switch state.backgroundState {
        case .dragging, .selected:
            return OpsSurface.selected(increasedContrast: increasedContrast)
        case .hovered:
            return OpsSurface.hoverStrong
        case .focused, .pressed:
            return OpsSurface.focused
        case .disabled:
            return .clear
        case .default:
            return OpsSurface.card
        }
    }
}

/// Bounded resources, requested from task lifecycle rather than SwiftUI body evaluation.
@MainActor
final class ShelfRowImageCache {
    static let shared = ShelfRowImageCache()
    private let cache = NSCache<NSString, NSImage>()
    private init() { cache.countLimit = 128; cache.totalCostLimit = 32 * 1024 * 1024 }
    func image(for item: ShelfPresentationItem, maximumPixelSize: Int = 96) -> NSImage? {
        let key: String
        let path: String
        let thumbnail: Bool
        if case .imageFile(let value) = item.thumbnail {
            path = value; key = "image:\(maximumPixelSize):\(value)"; thumbnail = true
        } else if case .file(let value, _) = item.icon {
            path = value; key = "icon:\(value)"; thumbnail = false
        } else { return nil }
        if let cached = cache.object(forKey: key as NSString) { return cached }
        // Decode only a small thumbnail instead of retaining full clipboard images.
        let image: NSImage
        if thumbnail {
            guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                    kCGImageSourceCreateThumbnailWithTransform: true
                  ] as CFDictionary) else { return nil }
            image = NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        } else { image = NSWorkspace.shared.icon(forFile: path) }
        let cost = image.representations.reduce(0) { total, representation in
            total + max(96 * 96 * 4, representation.pixelsWide * representation.pixelsHigh * 4)
        }
        cache.setObject(image, forKey: key as NSString, cost: max(96 * 96 * 4, cost))
        return image
    }
}
#endif

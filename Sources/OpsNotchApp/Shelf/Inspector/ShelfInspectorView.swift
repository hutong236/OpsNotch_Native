#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

/// Shares descriptors and action execution with rows; the inspector owns no item state.
struct ShelfInspectorView: View {
    let item: ShelfPresentationItem
    let language: AppLanguage
    let dispatcher: ShelfItemActionDispatcher
    @State private var resource: NSImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: OpsSpacing.small) {
            Text(L10n.text("shelfInspector", language)).font(OpsTypography.heading)
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().overlay(
                OpsSurface.divider(increasedContrast: colorSchemeContrast == .increased)
            )
            Text(item.title).font(OpsTypography.rowTitle).lineLimit(3)
            if let semanticLabel {
                Text(semanticLabel).font(OpsTypography.metadata).foregroundStyle(.secondary)
            }
            ForEach(Array(item.metadata.enumerated()), id: \.offset) { _, value in
                Text(value).font(OpsTypography.metadata).foregroundStyle(.secondary)
            }
            Button { dispatcher.perform(item.primaryAction.intent) } label: {
                Label(item.primaryAction.title, systemImage: item.primaryAction.symbolName)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityLabel(Text(item.primaryAction.title))
            Menu {
                ForEach(Array(item.secondaryActions.enumerated()), id: \.offset) { _, action in
                    Button(role: isDestructive(action) ? .destructive : nil) {
                        dispatcher.perform(action.intent)
                    } label: { Label(action.title, systemImage: action.symbolName) }
                }
            } label: { Label(L10n.text("shelfAdditionalActions", language), systemImage: "ellipsis") }
            .disabled(item.secondaryActions.isEmpty)
            .accessibilityLabel(Text(L10n.text("shelfAdditionalActions", language)))
        }
        .padding(OpsSpacing.medium)
        .background(OpsSurface.card)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(L10n.text("shelfInspector", language)))
        .animation(.easeOut(duration: OpsMotion.duration(for: .standard, reduceMotion: reduceMotion)), value: item.id)
        .task(id: item.id + resourceDescriptor) {
            resource = nil
            resource = ShelfRowImageCache.shared.image(for: item, maximumPixelSize: 640)
        }
    }

    private var semanticLabel: String? {
        if let badge = item.badge { return badge }
        guard let kind = item.semanticKind else { return nil }
        switch kind {
        case .file, .folder, .application, .text, .url, .action:
            return L10n.text("shelfKind_\(kind.rawValue)", language)
        case .ipv4: return L10n.text("semanticIP", language)
        case .ssh: return L10n.text("semanticSSH", language)
        case .command: return L10n.text("semanticCommand", language)
        case .path: return L10n.text("semanticPath", language)
        }
    }

    private var resourceDescriptor: String {
        switch item.icon {
        case .file(let path, _): return path
        case .symbol(let name): return name
        }
    }

    @ViewBuilder private var content: some View {
        switch item.preview {
        case .imageFile:
            ImageInspectorView(image: resource, title: item.title,
                               unavailable: L10n.text("shelfPreviewUnavailable", language))
        case .text(let text): TextInspectorView(text: text)
        case .quickLook(let path): FileInspectorView(path: path, image: resource, symbol: fallbackSymbol)
        case .unavailable:
            if item.semanticKind == .url {
                URLInspectorView(url: item.subtitle)
            } else {
                // Folder, application and safe-action/desktop descriptors use a generic inspector.
                FileInspectorView(path: item.subtitle, image: resource, symbol: fallbackSymbol)
            }
        }
    }

    private var fallbackSymbol: String {
        switch item.icon {
        case .symbol(let name), .file(_, let name): return name
        }
    }
    private func isDestructive(_ action: ShelfPresentationItem.Action) -> Bool {
        if case .removeShelfItem = action.intent { return true }
        return false
    }
}
#endif

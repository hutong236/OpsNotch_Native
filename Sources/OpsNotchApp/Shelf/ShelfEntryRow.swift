#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

/// Temporary integration boundary until the snapshot provider owns presentation invalidation.
/// A row's hover/selection updates do not normalize source content again.
struct ShelfEntryRow: View {
    @ObservedObject var model: AppModel
    let clipboard: ClipboardManager
    let entry: QuickShelfEntry
    @State private var presentation: ShelfPresentationItem?

    private struct Input: Equatable {
        let entry: QuickShelfEntry
        let language: AppLanguage
        let workingSet: Set<UUID>
    }
    private var input: Input {
        Input(entry: entry, language: model.language, workingSet: Set(model.settings.workingSetItemIDs))
    }
    private var state: OpsVisualState {
        if let item = entry.shelfItem, model.selection.contains(item.id) { return .selected }
        return model.highlightedQuickEntryID == entry.id ? .focused : .default
    }
    var body: some View {
        Group {
            if let presentation {
                ShelfRow(item: presentation, visualState: state,
                         onPrimaryAction: { activate(presentation) },
                         onSecondaryAction: { dispatcher.perform($0.intent) },
                         additionalActionsLabel: L10n.text("shelfAdditionalActions", model.language),
                         dragItems: entry.shelfItem.map { model.selectedItems(including: $0) } ?? [],
                         dragLabel: L10n.text("dragHandle", model.language))
            } else {
                Color.clear.frame(height: OpsControlMetrics.rowHeight)
            }
        }
        .onAppear { updatePresentation() }
        .onChange(of: input) { _ in updatePresentation() }
        .onHover { if $0 { model.highlightedQuickEntryID = entry.id } }
    }
    private var dispatcher: ShelfItemActionDispatcher { ShelfItemActionDispatcher(model: model, clipboard: clipboard) }
    private func updatePresentation() {
        presentation = ShelfPresentationAdapter.adapt(entry, language: model.language,
            semanticKind: entry.shelfItem.map { model.semanticKind(for: $0) },
            workingSetItemIDs: Set(model.settings.workingSetItemIDs))
    }
    private func activate(_ presentation: ShelfPresentationItem) {
        model.highlightedQuickEntryID = entry.id
        if let item = entry.shelfItem {
            let flags = NSEvent.modifierFlags
            if flags.contains(.command) || flags.contains(.shift) {
                model.toggleSelection(item)
                return
            }
            model.selection.removeAll()
        }
        dispatcher.perform(presentation.primaryAction.intent)
    }
}
#endif

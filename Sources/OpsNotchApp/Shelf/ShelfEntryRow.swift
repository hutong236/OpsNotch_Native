#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

/// Integration boundary consuming the provider's shared presentation snapshot.
struct ShelfEntryRow: View {
    @ObservedObject var model: AppModel
    @ObservedObject var experience: ShelfExperienceModel
    let clipboard: ClipboardManager
    let entry: QuickShelfEntry

    init(model: AppModel, clipboard: ClipboardManager, entry: QuickShelfEntry) {
        self.model = model
        self.experience = model.experience
        self.clipboard = clipboard
        self.entry = entry
    }

    private var state: OpsVisualState {
        if let item = entry.shelfItem, experience.selection.contains(item.id) { return .selected }
        return experience.highlightedQuickEntryID == entry.id ? .focused : .default
    }
    var body: some View {
        Group {
            if let presentation = model.quickShelfSnapshot.presentationByID[entry.id] {
                ShelfRow(item: presentation, visualState: state,
                         onPrimaryAction: { activate(presentation) },
                         onSecondaryAction: { dispatcher.perform($0.intent) },
                         additionalActionsLabel: L10n.text("shelfAdditionalActions", model.language),
                         dragItems: entry.shelfItem.map { experience.selectedItems(including: $0) } ?? [],
                         dragLabel: L10n.text("dragHandle", model.language))
            } else {
                Color.clear.frame(height: OpsControlMetrics.rowHeight)
            }
        }
        .onHover { if $0 { experience.highlightedQuickEntryID = entry.id } }
    }
    private var dispatcher: ShelfItemActionDispatcher { ShelfItemActionDispatcher(model: model, clipboard: clipboard) }
    private func activate(_ presentation: ShelfPresentationItem) {
        experience.highlightedQuickEntryID = entry.id
        if let item = entry.shelfItem {
            let flags = NSEvent.modifierFlags
            if flags.contains(.command) || flags.contains(.shift) {
                experience.toggleSelection(item)
                return
            }
            experience.selection.removeAll()
        }
        dispatcher.perform(presentation.primaryAction.intent)
    }
}
#endif

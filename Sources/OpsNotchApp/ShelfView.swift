#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

struct ShelfRootView: View {
    @ObservedObject var model: AppModel
    let clipboard: ClipboardManager
    let presentation: ShelfWindowController.Presentation

    var body: some View {
        Group {
            switch presentation {
            case .expanded: expanded
            case .drop: dropView
            case .peek: peekView
            }
        }
        .onHover { model.setShelfHovered($0) }
        .animation(.easeOut(duration: 0.16), value: presentation)
    }

    private var expanded: some View {
        VStack(spacing: 0) {
            header
            search
            if !model.selection.isEmpty { selectionBar }
            Divider().opacity(0.35)
            content
            Divider().opacity(0.35)
            footer
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        .padding(6)
        .sheet(item: $model.editorDraft) { draft in
            ItemEditorView(model: model, draft: draft)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text("quickShelf", model.language)).font(.system(size: 13, weight: .semibold))
                Text("File · Text · URL · Mac").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button(L10n.text("addText", model.language)) { model.editorDraft = .text() }
                Button(L10n.text("addFile", model.language)) { model.chooseFiles() }
                Button(L10n.text("addFolder", model.language)) { model.chooseFolder() }
                Divider()
                Button(L10n.text("addURL", model.language)) { model.editorDraft = .url() }
                Button(L10n.text("addApp", model.language)) { model.chooseApplication() }
                Button(L10n.text("addAction", model.language)) { model.editorDraft = .action() }
            } label: {
                Image(systemName: "plus").frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 9)
    }

    private var search: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(L10n.text("search", model.language), text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
            if !model.query.isEmpty {
                Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
    }

    private var selectionBar: some View {
        HStack {
            Text("\(L10n.text("selected", model.language)) \(model.selection.count)")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            Button {
                model.copySelected(using: clipboard)
            } label: { Label(L10n.text("copySelected", model.language), systemImage: "doc.on.doc") }
                .buttonStyle(.borderless)
            Button(role: .destructive) {
                model.remove(model.selection)
            } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
            Button { model.selection.removeAll() } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
        }
        .font(.system(size: 10))
        .padding(.horizontal, 13)
        .frame(height: 28)
        .background(Color.accentColor.opacity(0.08))
    }

    @ViewBuilder
    private var content: some View {
        let groups = model.grouped
        if groups.pinned.isEmpty && groups.recent.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray").font(.system(size: 24, weight: .light)).foregroundStyle(.secondary)
                Text(L10n.text("empty", model.language)).font(.system(size: 12, weight: .semibold))
                Text(L10n.text("emptyHint", model.language)).font(.system(size: 10)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(30)
        } else {
            ScrollView {
                LazyVStack(spacing: 3) {
                    if !groups.pinned.isEmpty {
                        SectionHeader(title: L10n.text("pinned", model.language), count: groups.pinned.count)
                        ForEach(groups.pinned) { item in ShelfRowView(model: model, clipboard: clipboard, item: item) }
                    }
                    if !groups.recent.isEmpty {
                        SectionHeader(title: L10n.text("recent", model.language), count: groups.recent.count, action: L10n.text("clear", model.language), onAction: model.clearRecent)
                        ForEach(groups.recent) { item in ShelfRowView(model: model, clipboard: clipboard, item: item) }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(L10n.text("clipboardHint", model.language))
            Spacer()
            Text("Pinned + Recent")
        }
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 13)
        .frame(height: 28)
        .overlay(alignment: .top) {
            if let toast = model.toast {
                Text(toast)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .offset(y: -36)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var dropView: some View {
        HStack(spacing: 13) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 27))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("dropTitle", model.language)).font(.system(size: 12, weight: .semibold))
                Text(L10n.text("dropHint", model.language)).font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(model.settings.addMode == .copy ? L10n.text("dropCopy", model.language) : L10n.text("dropReference", model.language))
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.blue.opacity(0.3), lineWidth: 0.5))
        .padding(6)
    }

    private var peekView: some View {
        HStack {
            Image(systemName: "tray.full").foregroundStyle(.secondary)
            Text(L10n.text("quickShelf", model.language)).font(.system(size: 11, weight: .semibold))
            Spacer()
            Text("\(model.grouped.pinned.count) · \(model.grouped.recent.count)").font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(6)
    }
}

private struct SectionHeader: View {
    let title: String
    let count: Int
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            Text("\(count)").font(.system(size: 8)).foregroundStyle(.tertiary)
            Spacer()
            if let action, let onAction {
                Button(action, action: onAction).buttonStyle(.borderless).font(.system(size: 9))
            }
        }
        .padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 2)
    }
}

struct ShelfRowView: View {
    @ObservedObject var model: AppModel
    let clipboard: ClipboardManager
    let item: ShelfItem
    @State private var hovered = false

    private var selected: Bool { model.selection.contains(item.id) }

    var body: some View {
        HStack(spacing: 8) {
            if selected {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue).font(.system(size: 13))
            }
            itemIcon
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                Text(subtitle).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 4)

            if hovered || selected {
                actionButtons
            }

            NativeDragSourceView(items: model.selectedItems(including: item))
                .frame(width: 16, height: 18)
                .help(L10n.text("dragHandle", model.language))
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
        .background(selected ? Color.accentColor.opacity(0.12) : hovered ? Color.primary.opacity(0.055) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture {
            let flags = NSEvent.modifierFlags
            if flags.contains(.command) || flags.contains(.shift) {
                model.toggleSelection(item)
            } else {
                model.selection.removeAll()
                ItemActionService.performDefault(item, clipboard: clipboard, model: model)
            }
        }
        .contextMenu {
            if item.kind == .text || item.kind == .url {
                Button(L10n.text("copy", model.language)) {
                    clipboard.copyFromApp(item.content); model.showToast(L10n.text("copied", model.language))
                }
            }
            if [.file, .folder].contains(item.kind) {
                Button(L10n.text("quickLook", model.language)) { QuickLookService.shared.preview(item) }
            }
            if [.file, .folder, .application].contains(item.kind) {
                Button(L10n.text("reveal", model.language)) { ItemActionService.reveal(item) }
            }
            Divider()
            Button(item.pinned ? L10n.text("unpin", model.language) : L10n.text("pin", model.language)) { model.togglePin(item) }
            Button(L10n.text("edit", model.language)) { model.beginEdit(item) }
            Button(L10n.text("remove", model.language), role: .destructive) { model.remove(Set([item.id])) }
        }
    }

    @ViewBuilder private var itemIcon: some View {
        if let icon = ItemActionService.icon(for: item) {
            Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: symbolName).font(.system(size: 15)).foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 7) {
            if item.kind == .text || item.kind == .url {
                Button {
                    clipboard.copyFromApp(item.content); model.showToast(L10n.text("copied", model.language))
                } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain)
            }
            if item.kind == .file {
                Button { QuickLookService.shared.preview(item) } label: { Image(systemName: "eye") }.buttonStyle(.plain)
            }
            Button { model.togglePin(item) } label: { Image(systemName: item.pinned ? "pin.slash" : "pin") }.buttonStyle(.plain)
        }
        .foregroundStyle(.secondary)
        .font(.system(size: 11))
    }

    private var symbolName: String {
        switch item.kind {
        case .text: return "doc.text"
        case .url: return "globe"
        case .action: return "play.circle"
        case .file: return "doc"
        case .folder: return "folder"
        case .application: return "app"
        }
    }

    private var subtitle: String {
        switch item.kind {
        case .text, .url: return item.content.replacingOccurrences(of: "\n", with: " ")
        case .file, .folder, .application: return item.content
        case .action: return item.actionKind == .openURL ? "HTTP/HTTPS" : "Local path"
        }
    }
}

struct ItemEditorView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var draft: ItemDraft

    init(model: AppModel, draft: ItemDraft) {
        self.model = model
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title).font(.headline)
            TextField(L10n.text("name", model.language), text: $draft.title)
            TextEditor(text: $draft.content)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 100)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.secondary.opacity(0.25)))
            if draft.mode == .newAction {
                Picker("", selection: $draft.actionKind) {
                    Text(L10n.text("safePath", model.language)).tag(SafeActionKind.openPath)
                    Text(L10n.text("safeURL", model.language)).tag(SafeActionKind.openURL)
                }.pickerStyle(.segmented)
            }
            HStack {
                Spacer()
                Button(L10n.text("cancel", model.language)) { model.editorDraft = nil; dismiss() }
                Button(L10n.text("save", model.language)) { model.saveDraft(draft); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 390)
    }

    private var title: String {
        switch draft.mode {
        case .newText: return L10n.text("addText", model.language)
        case .newURL: return L10n.text("addURL", model.language)
        case .newAction: return L10n.text("addAction", model.language)
        case .edit: return L10n.text("edit", model.language)
        }
    }
}
#endif

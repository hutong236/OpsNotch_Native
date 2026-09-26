#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import OpsNotchCore

struct ShelfRootView: View {
    @ObservedObject var model: AppModel
    let clipboard: ClipboardManager
    let presentation: ShelfWindowController.Presentation
    @FocusState private var searchFocused: Bool

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
            filterChips
            if !model.selection.isEmpty { selectionBar }
            Divider().opacity(0.35)
            workspace
            Divider().opacity(0.35)
            footer
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        .padding(6)
        .sheet(item: $model.editorDraft) { draft in
            ItemEditorView(model: model, draft: draft)
        }
        .onReceive(model.$focusRequestToken) { token in
            guard token != nil else { return }
            model.refreshSmartContext()
            if searchFocused {
                searchFocused = false
                DispatchQueue.main.async { searchFocused = true }
            } else {
                searchFocused = true
            }
            model.resetQuickHighlight()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text("quickShelf", model.language)).font(.system(size: 14, weight: .semibold))
                Text(model.language == .zhCN ? "剪贴板 · 收藏 · Finder · 快速操作" : "Clipboard · Favorites · Finder · Quick Actions")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: model.settings.shelfKeepOpen ? "pin.fill" : "pin")
                .foregroundStyle(model.settings.shelfKeepOpen ? Color.accentColor : Color.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .onTapGesture { toggleKeepOpen() }
                .help(L10n.text(model.settings.shelfKeepOpen ? "keepShelfOpenOff" : "keepShelfOpenOn", model.language))
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

    /// 常驻展开（图钉）开关:与条目级置顶(pin/pin.slash)区分,作用于整个 Shelf 窗口。
    /// 关闭时立即收起(Esc 语义之外的显式隐藏);开启后保持当前展开。
    private func toggleKeepOpen() {
        let turningOn = !model.settings.shelfKeepOpen
        model.updateSettings { $0.shelfKeepOpen = turningOn }
        if !turningOn { model.requestHide?() }
    }

    private var search: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(L10n.text("searchUnified", model.language), text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($searchFocused)
            if !model.query.isEmpty {
                Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(.primary.opacity(0.075), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(searchFocused ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.05), lineWidth: 0.7)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
    }

    private var filterChips: some View {
        HStack(spacing: 6) {
            ForEach(filterChipsData, id: \.0) { filter, title in
                Button {
                    model.setKindFilter(to: filter)
                } label: {
                    Text(title)
                        .font(.system(size: 10, weight: model.kindFilter == filter ? .semibold : .regular))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(
                            model.kindFilter == filter ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.05),
                            in: Capsule()
                        )
                        .foregroundStyle(model.kindFilter == filter ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var filterChipsData: [(ShelfKindFilter, String)] {
        [
            (.all, L10n.text("filterAll", model.language)),
            (.file, L10n.text("filterFile", model.language)),
            (.text, L10n.text("filterText", model.language)),
            (.url, L10n.text("filterURL", model.language)),
            (.application, L10n.text("filterApp", model.language)),
            (.action, L10n.text("filterAction", model.language)),
        ]
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
        let desktopEntries = model.visibleDesktopEntries
        let working = model.workingSetItems
        let finderEntries = model.visibleFinderEntries
        let localEntries = model.visibleLocalEntries
        let isEmpty = desktopEntries.isEmpty
            && finderEntries.isEmpty
            && working.isEmpty
            && groups.pinned.isEmpty
            && groups.recent.isEmpty
            && localEntries.isEmpty

        if isEmpty {
            if model.query.isEmpty && model.kindFilter == .all {
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.system(size: 24, weight: .light)).foregroundStyle(.secondary)
                    Text(L10n.text("empty", model.language)).font(.system(size: 12, weight: .semibold))
                    Text(L10n.text("emptyHint", model.language)).font(.system(size: 10)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(30)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle").font(.system(size: 24, weight: .light)).foregroundStyle(.secondary)
                    Text(L10n.text("noMatch", model.language)).font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(30)
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 3) {
                        if !desktopEntries.isEmpty {
                            SectionHeader(title: L10n.text("desktop", model.language), count: desktopEntries.count)
                            ForEach(desktopEntries) { entry in
                                DesktopQuickShelfRowView(model: model, entry: entry)
                                    .id(entry.id)
                            }
                        }

                        if !finderEntries.isEmpty {
                            SectionHeader(title: L10n.text("finderQuickPaths", model.language), count: finderEntries.count)
                            ForEach(finderEntries) { entry in
                                FinderQuickShelfRowView(model: model, clipboard: clipboard, entry: entry)
                                    .id(entry.id)
                            }
                        }

                        if !working.isEmpty {
                            SectionHeader(
                                title: L10n.text("workingSet", model.language),
                                count: working.count,
                                action: L10n.text("clear", model.language),
                                onAction: model.clearWorkingSet
                            )
                            ForEach(working) { item in
                                ShelfRowView(model: model, clipboard: clipboard, item: item)
                                    .id(model.quickEntryID(for: item))
                            }
                        }

                        if !groups.pinned.isEmpty {
                            SectionHeader(title: L10n.text("pinned", model.language), count: groups.pinned.count)
                            ForEach(groups.pinned) { item in
                                ShelfRowView(model: model, clipboard: clipboard, item: item)
                                    .id(model.quickEntryID(for: item))
                            }
                        }

                        if !groups.recent.isEmpty {
                            SectionHeader(
                                title: L10n.text("recent", model.language),
                                count: groups.recent.count,
                                action: L10n.text("clear", model.language),
                                onAction: model.clearRecent
                            )
                            ForEach(groups.recent) { item in
                                ShelfRowView(model: model, clipboard: clipboard, item: item)
                                    .id(model.quickEntryID(for: item))
                            }
                        }

                        if !localEntries.isEmpty {
                            SectionHeader(title: L10n.text("localResults", model.language), count: localEntries.count)
                            ForEach(localEntries) { entry in
                                LocalQuickShelfRowView(model: model, clipboard: clipboard, entry: entry)
                                    .id(entry.id)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                }
                .onChange(of: model.highlightedQuickEntryID) { id in
                    guard let id else { return }
                    DispatchQueue.main.async {
                        proxy.scrollTo(id)
                    }
                }
            }
        }
    }

    private var workspace: some View {
        HStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let item = model.highlightedShelfItem {
                Divider().opacity(0.35)
                ClipboardPreviewPane(model: model, clipboard: clipboard, item: item)
                    .frame(width: 258)
                    .transition(.opacity)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(L10n.text("clipboardHint", model.language))
            Spacer()
            Text(contextLabel)
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

    private var contextLabel: String {
        switch model.appContext {
        case .finder: return "Smart · Finder"
        case .terminal: return "Smart · Terminal"
        case .browser: return "Smart · Browser"
        case .generic: return L10n.text("unifiedFooter", model.language)
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
            Text("\(model.visibleItems.count)").font(.system(size: 9)).foregroundStyle(.secondary)
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

private struct DesktopQuickShelfRowView: View {
    @ObservedObject var model: AppModel
    let entry: QuickShelfEntry
    @State private var hovered = false

    private var highlighted: Bool { model.highlightedQuickEntryID == entry.id }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                if let subtitle = entry.desktopSubtitle {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "return")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
        .contentShape(Rectangle())
        .background(hovered ? Color.primary.opacity(0.055) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.75), lineWidth: 1)
            }
        }
        .onHover { hovered = $0 }
        .onTapGesture {
            guard let command = entry.desktopCommand else { return }
            model.requestDesktopCommand?(command)
        }
    }
}

private struct FinderQuickShelfRowView: View {
    @ObservedObject var model: AppModel
    let clipboard: ClipboardManager
    let entry: QuickShelfEntry
    @State private var hovered = false

    private var highlighted: Bool { model.highlightedQuickEntryID == entry.id }
    private var path: String { entry.finderPath ?? "" }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                    Text(path).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { model.openFinderEntry(entry) }

            Spacer(minLength: 4)

            if hovered {
                Image(systemName: "doc.on.doc")
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        clipboard.copyFromApp(path)
                        model.showToast(L10n.text("pathCopied", model.language))
                    }
                Image(systemName: "arrow.up.right.square")
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
                    .onTapGesture { model.openFinderEntry(entry) }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
        .background(hovered ? Color.primary.opacity(0.055) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.white.opacity(0.55), lineWidth: 1)
                    .background(Color.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .contextMenu {
            Button(L10n.text("openFolder", model.language)) { model.openFinderEntry(entry) }
            Button(L10n.text("copyPath", model.language)) {
                clipboard.copyFromApp(path)
                model.showToast(L10n.text("pathCopied", model.language))
            }
        }
    }
}

private struct LocalQuickShelfRowView: View {
    @ObservedObject var model: AppModel
    let clipboard: ClipboardManager
    let entry: QuickShelfEntry
    @State private var hovered = false

    private var highlighted: Bool { model.highlightedQuickEntryID == entry.id }
    private var path: String { entry.localPath ?? "" }
    private var isDirectory: Bool { entry.localIsDirectory ?? false }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                    Text(path).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { model.openLocalEntry(entry, using: clipboard) }

            Spacer(minLength: 4)
            if hovered {
                if !isDirectory {
                    Image(systemName: "eye")
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                        .onTapGesture { preview() }
                }
                Image(systemName: isDirectory ? "arrow.up.right.square" : "doc.on.doc")
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
                    .onTapGesture { model.openLocalEntry(entry, using: clipboard) }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
        .background(hovered ? Color.primary.opacity(0.055) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.white.opacity(0.55), lineWidth: 1)
                    .background(Color.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .contextMenu {
            Button(isDirectory ? L10n.text("openFolder", model.language) : L10n.text("copy", model.language)) {
                model.openLocalEntry(entry, using: clipboard)
            }
            if !isDirectory {
                Button(L10n.text("quickLook", model.language)) { preview() }
                Button(L10n.text("reveal", model.language)) {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                }
            }
            Button(L10n.text("copyPath", model.language)) {
                clipboard.copyFromApp(path)
                model.showToast(L10n.text("pathCopied", model.language))
            }
        }
    }

    private func preview() {
        let item = ShelfItem(kind: .file, title: entry.title, content: path, storageMode: .reference)
        QuickLookService.shared.preview(item)
    }
}

struct ShelfRowView: View {
    @ObservedObject var model: AppModel
    let clipboard: ClipboardManager
    let item: ShelfItem
    @State private var hovered = false

    private var selected: Bool { model.selection.contains(item.id) }
    private var highlighted: Bool { model.highlightedQuickEntryID == model.quickEntryID(for: item) }

    var body: some View {
        HStack(spacing: 8) {
            if selected {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue).font(.system(size: 13))
            }
            leading
                .contentShape(Rectangle())
                .onTapGesture { handleRowTap() }
            Spacer(minLength: 4)

            if hovered || selected {
                actionButtons
            }

            NativeDragSourceView(items: model.selectedItems(including: item))
                .frame(width: 16, height: 18)
                .help(L10n.text("dragHandle", model.language))
        }
        .padding(.horizontal, 9)
        .frame(height: 58)
        .background(
            selected
                ? Color.accentColor.opacity(0.13)
                : hovered
                    ? Color.primary.opacity(0.075)
                    : Color.primary.opacity(0.028),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay {
            if highlighted && !selected {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.white.opacity(0.55), lineWidth: 1)
                    .background(Color.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .contextMenu {
            if item.kind == .text || item.kind == .url {
                Button(L10n.text("copy", model.language)) {
                    clipboard.copyFromApp(item.content)
                    model.recordUse(item.id)
                    model.showToast(L10n.text("copied", model.language))
                }
            } else if item.clipboardImage {
                Button(L10n.text("copy", model.language)) {
                    if clipboard.copyImageFile(item.content) {
                        model.recordUse(item.id)
                        model.showToast(L10n.text("copied", model.language))
                    }
                }
            }
            if [.file, .folder].contains(item.kind) {
                Button(L10n.text("quickLook", model.language)) { QuickLookService.shared.preview(item) }
            }
            if ItemPreviewKind.isPreviewable(item) {
                Button(L10n.text("zoomPreview", model.language)) {
                    FloatingPreviewController.shared.show(item: item, language: model.language)
                }
            }
            if [.file, .folder, .application].contains(item.kind) {
                Button(L10n.text("reveal", model.language)) { ItemActionService.reveal(item) }
            }
            Divider()
            Button(model.isInWorkingSet(item) ? L10n.text("workingSetRemove", model.language) : L10n.text("workingSetAdd", model.language)) {
                model.toggleWorkingSet(item)
            }
            Button(item.pinned ? L10n.text("unpin", model.language) : L10n.text("pin", model.language)) { model.togglePin(item) }
            Button(L10n.text("edit", model.language)) { model.beginEdit(item) }
            Button(L10n.text("remove", model.language), role: .destructive) { model.remove(Set([item.id])) }
        }
    }

    private var leading: some View {
        HStack(spacing: 9) {
            itemIcon
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(item.title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                    if item.pinned {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.accentColor)
                    }
                    if let badge = semanticBadgeText {
                        Text(badge)
                            .font(.system(size: 7.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                }
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(metadata)
                    .font(.system(size: 8.3))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private func handleRowTap() {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) || flags.contains(.shift) {
            model.toggleSelection(item)
        } else {
            model.selection.removeAll()
            ItemActionService.performDefault(item, clipboard: clipboard, model: model)
        }
    }

    @ViewBuilder private var itemIcon: some View {
        if ItemPreviewKind.isImagePath(item.content), let image = NSImage(contentsOfFile: item.content) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
        } else if let icon = ItemActionService.icon(for: item) {
            Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: symbolName).font(.system(size: 16)).foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 7) {
            if item.kind == .text || item.kind == .url {
                actionIcon("doc.on.doc") {
                    clipboard.copyFromApp(item.content)
                    model.recordUse(item.id)
                    model.showToast(L10n.text("copied", model.language))
                }
            } else if item.clipboardImage {
                actionIcon("doc.on.doc") {
                    if clipboard.copyImageFile(item.content) {
                        model.recordUse(item.id)
                        model.showToast(L10n.text("copied", model.language))
                    }
                }
            }
            if item.kind == .file {
                actionIcon("eye") { QuickLookService.shared.preview(item) }
            }
            if ItemPreviewKind.isPreviewable(item) {
                actionIcon("arrow.up.left.and.arrow.down.right") {
                    FloatingPreviewController.shared.show(item: item, language: model.language)
                }
            }
            actionIcon(model.isInWorkingSet(item) ? "tray.full.fill" : "tray.full") { model.toggleWorkingSet(item) }
            actionIcon(item.pinned ? "pin.slash" : "pin") { model.togglePin(item) }
        }
        .foregroundStyle(.secondary)
        .font(.system(size: 11))
    }

    private func actionIcon(_ symbol: String, action: @escaping () -> Void) -> some View {
        Image(systemName: symbol)
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
            .onTapGesture { action() }
    }

    private var semanticBadgeText: String? {
        switch model.semanticKind(for: item) {
        case .ipv4: return L10n.text("semanticIP", model.language)
        case .ssh: return L10n.text("semanticSSH", model.language)
        case .command: return L10n.text("semanticCommand", model.language)
        case .path: return L10n.text("semanticPath", model.language)
        case .url where item.kind == .text: return L10n.text("semanticURL", model.language)
        default: return nil
        }
    }

    private var symbolName: String {
        switch model.semanticKind(for: item) {
        case .ipv4: return "network"
        case .ssh: return "terminal"
        case .command: return "chevron.left.forwardslash.chevron.right"
        case .path: return "point.topleft.down.curvedto.point.bottomright.up"
        default:
            switch item.kind {
            case .text: return "doc.text"
            case .url: return "globe"
            case .action: return "play.circle"
            case .file: return "doc"
            case .folder: return "folder"
            case .application: return "app"
            }
        }
    }

    private var subtitle: String {
        switch item.kind {
        case .text, .url: return item.content.replacingOccurrences(of: "\n", with: " ")
        case .file, .folder, .application: return item.clipboardImage
            ? (model.language == .zhCN ? "剪贴板图片" : "Clipboard image")
            : item.content
        case .action: return item.actionKind == .openURL ? "HTTP/HTTPS" : "Local path"
        }
    }

    private var metadata: String {
        let source = item.sourceAppName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceText = (source?.isEmpty == false) ? source! : kindLabel
        return "\(sourceText) · \(relativeTime)"
    }

    private var kindLabel: String {
        if item.clipboardImage { return model.language == .zhCN ? "图片" : "Image" }
        switch item.kind {
        case .text: return model.language == .zhCN ? "文本" : "Text"
        case .url: return "URL"
        case .file: return model.language == .zhCN ? "文件" : "File"
        case .folder: return model.language == .zhCN ? "文件夹" : "Folder"
        case .application: return model.language == .zhCN ? "应用" : "App"
        case .action: return model.language == .zhCN ? "操作" : "Action"
        }
    }

    private var relativeTime: String {
        let interval = max(0, Int(ShelfClock.now() - item.updatedAt))
        if interval < 60 { return model.language == .zhCN ? "刚刚" : "now" }
        if interval < 3600 { return model.language == .zhCN ? "\(interval / 60) 分钟前" : "\(interval / 60)m ago" }
        if interval < 86_400 { return model.language == .zhCN ? "\(interval / 3600) 小时前" : "\(interval / 3600)h ago" }
        return model.language == .zhCN ? "\(interval / 86_400) 天前" : "\(interval / 86_400)d ago"
    }
}

private struct ClipboardPreviewPane: View {
    @ObservedObject var model: AppModel
    let clipboard: ClipboardManager
    let item: ShelfItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: item.clipboardImage ? "photo" : "rectangle.and.text.magnifyingglass")
                    .foregroundStyle(.secondary)
                Text(model.language == .zhCN ? "预览" : "Preview")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Button {
                    model.togglePin(item)
                } label: {
                    Image(systemName: item.pinned ? "star.fill" : "star")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(item.pinned ? L10n.text("unpin", model.language) : L10n.text("pin", model.language))

                if ItemPreviewKind.isPreviewable(item) {
                    Button {
                        FloatingPreviewController.shared.show(item: item, language: model.language)
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.text("zoomPreview", model.language))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 38)

            Divider().opacity(0.25)

            previewContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.25)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(2)
                HStack(spacing: 5) {
                    if let source = item.sourceAppName, !source.isEmpty {
                        Label(source, systemImage: "app")
                    }
                    Label(relativeTime, systemImage: "clock")
                }
                .font(.system(size: 8.5))
                .foregroundStyle(.secondary)
                if item.useCount > 0 {
                    Text(model.language == .zhCN ? "已使用 \(item.useCount) 次" : "Used \(item.useCount) times")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
        }
        .background(Color.primary.opacity(0.018))
    }

    @ViewBuilder
    private var previewContent: some View {
        if ItemPreviewKind.isImagePath(item.content), let image = NSImage(contentsOfFile: item.content) {
            VStack(spacing: 10) {
                Spacer(minLength: 10)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 12)
                if item.clipboardImage {
                    Button(model.language == .zhCN ? "复制图片" : "Copy Image") {
                        if clipboard.copyImageFile(item.content) {
                            model.recordUse(item.id)
                            model.showToast(L10n.text("copied", model.language))
                        }
                    }
                    .buttonStyle(.borderless)
                }
                Spacer(minLength: 10)
            }
        } else if item.kind == .text || item.kind == .url {
            ScrollView {
                Text(item.content)
                    .font(.system(size: 10.5, design: item.kind == .text ? .monospaced : .default))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
        } else {
            VStack(spacing: 12) {
                Spacer()
                if let icon = ItemActionService.icon(for: item) {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                } else {
                    Image(systemName: "doc")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(.secondary)
                }
                Text(item.content)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .lineLimit(6)
                    .padding(.horizontal, 14)
                Spacer()
            }
        }
    }

    private var relativeTime: String {
        let interval = max(0, Int(ShelfClock.now() - item.updatedAt))
        if interval < 60 { return model.language == .zhCN ? "刚刚" : "now" }
        if interval < 3600 { return model.language == .zhCN ? "\(interval / 60) 分钟前" : "\(interval / 60)m ago" }
        if interval < 86_400 { return model.language == .zhCN ? "\(interval / 3600) 小时前" : "\(interval / 3600)h ago" }
        return model.language == .zhCN ? "\(interval / 86_400) 天前" : "\(interval / 86_400)d ago"
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
            if let hint = inlineHint {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button(L10n.text("cancel", model.language)) { model.editorDraft = nil; dismiss() }
                Button(L10n.text("save", model.language)) {
                    if model.saveDraft(draft) { dismiss() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!draftIsValid)
            }
        }
        .padding(18)
        .frame(width: 390)
    }

    /// 草稿能否保存:新建文字/编辑要求非空,添加网址与安全操作按类型实时校验。
    private var draftIsValid: Bool {
        switch draft.mode {
        case .newText, .edit:
            return !draft.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .newURL:
            return SafeActionValidator.isHTTPURL(draft.content)
        case .newAction:
            return SafeActionValidator.validate(kind: draft.actionKind, content: draft.content)
        }
    }

    /// 就地的无效原因提示;内容为空或仍是初始模板时保持安静。
    private var inlineHint: String? {
        if draftIsValid { return nil }
        let content = draft.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }
        switch draft.mode {
        case .newURL:
            return content == "https://" ? nil : L10n.text("invalidURLInput", model.language)
        case .newAction:
            return draft.actionKind == .openPath
                ? L10n.text("invalidPathInput", model.language)
                : L10n.text("invalidURLInput", model.language)
        case .newText, .edit:
            return nil
        }
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

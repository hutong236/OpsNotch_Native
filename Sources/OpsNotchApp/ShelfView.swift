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
        .animation(OpsMotion.quick, value: presentation)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: OpsRadius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OpsRadius.panel, style: .continuous).strokeBorder(OpsSurface.panelStroke, lineWidth: 0.5))
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
                Text(L10n.text("quickShelf", model.language)).font(OpsTypography.heading)
                Text(model.language == .zhCN ? "剪贴板 · 收藏 · Finder · 快速操作" : "Clipboard · Favorites · Finder · Quick Actions")
                    .font(OpsTypography.shelfSubtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            OpsIconButton(
                systemName: model.settings.shelfKeepOpen ? "pin.fill" : "pin",
                accessibilityLabel: L10n.text(
                    model.settings.shelfKeepOpen ? "keepShelfOpenOff" : "keepShelfOpenOn",
                    model.language
                ),
                selected: model.settings.shelfKeepOpen,
                action: toggleKeepOpen
            )
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
        ShelfCommandBar(query: $model.query, language: model.language, focused: $searchFocused)
            .padding(.horizontal, OpsSpacing.medium)
            .padding(.bottom, OpsSpacing.small)
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
        .frame(height: OpsControlMetrics.footerHeight)
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
            ShelfEmptyState(filtered: !model.query.isEmpty || model.kindFilter != .all, language: model.language)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 3) {
                        if !desktopEntries.isEmpty {
                            ShelfSectionView(title: L10n.text("desktop", model.language), count: desktopEntries.count)
                            ForEach(desktopEntries) { entry in
                                ShelfEntryRow(model: model, clipboard: clipboard, entry: entry)
                                    .id(entry.id)
                            }
                        }

                        if !finderEntries.isEmpty {
                            ShelfSectionView(title: L10n.text("finderQuickPaths", model.language), count: finderEntries.count)
                            ForEach(finderEntries) { entry in
                                ShelfEntryRow(model: model, clipboard: clipboard, entry: entry)
                                    .id(entry.id)
                            }
                        }

                        if !working.isEmpty {
                            ShelfSectionView(
                                title: L10n.text("workingSet", model.language),
                                count: working.count,
                                action: L10n.text("clear", model.language),
                                onAction: model.clearWorkingSet
                            )
                            ForEach(working) { item in
                                ShelfEntryRow(model: model, clipboard: clipboard, entry: .shelf(item))
                                    .id(model.quickEntryID(for: item))
                            }
                        }

                        if !groups.pinned.isEmpty {
                            ShelfSectionView(title: L10n.text("pinned", model.language), count: groups.pinned.count)
                            ForEach(groups.pinned) { item in
                                ShelfEntryRow(model: model, clipboard: clipboard, entry: .shelf(item))
                                    .id(model.quickEntryID(for: item))
                            }
                        }

                        if !groups.recent.isEmpty {
                            ShelfSectionView(
                                title: L10n.text("recent", model.language),
                                count: groups.recent.count,
                                action: L10n.text("clear", model.language),
                                onAction: model.clearRecent
                            )
                            ForEach(groups.recent) { item in
                                ShelfEntryRow(model: model, clipboard: clipboard, entry: .shelf(item))
                                    .id(model.quickEntryID(for: item))
                            }
                        }

                        if !localEntries.isEmpty {
                            ShelfSectionView(title: L10n.text("localResults", model.language), count: localEntries.count)
                            ForEach(localEntries) { entry in
                                ShelfEntryRow(model: model, clipboard: clipboard, entry: entry)
                                    .id(entry.id)
                            }
                        }
                    }
                    .padding(.horizontal, OpsSpacing.small)
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
                    .frame(width: OpsControlMetrics.inspectorWidth)
                    .transition(.opacity)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(shortcutHint)
            Spacer()
            Text(contextLabel)
        }
        .font(OpsTypography.metadata)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 13)
        .frame(height: OpsControlMetrics.footerHeight)
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

    private var shortcutHint: String {
        var parts = [L10n.text("shortcutUse", model.language)]
        if model.highlightedShelfItem != nil {
            parts.append(L10n.text("shortcutPin", model.language))
            parts.append(L10n.text("shortcutDelete", model.language))
        }
        if model.canPreviewHighlighted {
            parts.append(L10n.text("shortcutPreview", model.language))
        }
        return parts.joined(separator: " · ")
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
        .padding(.horizontal, OpsSpacing.large)
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
                    .clipShape(RoundedRectangle(cornerRadius: OpsRadius.control, style: .continuous))
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

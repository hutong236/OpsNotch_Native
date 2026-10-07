#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import OpsNotchCore

struct ShelfRootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var experience: ShelfExperienceModel
    let clipboard: ClipboardManager
    let presentation: ShelfPresentationState
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    init(model: AppModel, clipboard: ClipboardManager, presentation: ShelfPresentationState) {
        self.model = model
        self.experience = model.experience
        self.clipboard = clipboard
        self.presentation = presentation
    }

    var body: some View {
        Group {
            switch presentation {
            case .expanded: expanded
            case .dropTarget: dropView
            case .peek: peekView
            case .confirmation, .hidden: EmptyView()
            }
        }
        .onHover { experience.setShelfHovered($0) }
        .animation(
            .easeOut(duration: OpsMotion.duration(for: .quick, reduceMotion: reduceMotion)),
            value: presentation
        )
    }

    private var expanded: some View {
        VStack(spacing: 0) {
            header
            search
            if !experience.selection.isEmpty { selectionBar }
            Divider().overlay(OpsSurface.divider(increasedContrast: increasedContrast))
            workspace
            Divider().overlay(OpsSurface.divider(increasedContrast: increasedContrast))
            footer
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: OpsRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OpsRadius.panel, style: .continuous)
                .strokeBorder(OpsSurface.panelStroke(increasedContrast: increasedContrast), lineWidth: increasedContrast ? 1 : 0.5)
        )
        .padding(OpsSpacing.small)
        .sheet(item: $experience.editorDraft) { draft in
            ItemEditorView(model: model, draft: draft)
        }
        .onReceive(experience.$focusRequestToken) { token in
            guard token != nil else { return }
            model.refreshSmartContext()
            if searchFocused {
                searchFocused = false
                DispatchQueue.main.async { searchFocused = true }
            } else {
                searchFocused = true
            }
            experience.resetQuickHighlight()
        }
    }

    private var header: some View {
        HStack(spacing: OpsSpacing.small) {
            VStack(alignment: .leading, spacing: OpsSpacing.micro) {
                Text(L10n.text("quickShelf", model.language)).font(OpsTypography.heading)
                Text(L10n.text("quickShelfSubtitle", model.language))
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
                Button(L10n.text("addText", model.language)) { experience.editorDraft = .text() }
                Button(L10n.text("addFile", model.language)) { model.chooseFiles() }
                Button(L10n.text("addFolder", model.language)) { model.chooseFolder() }
                Divider()
                Button(L10n.text("addURL", model.language)) { experience.editorDraft = .url() }
                Button(L10n.text("addApp", model.language)) { model.chooseApplication() }
                Button(L10n.text("addAction", model.language)) { experience.editorDraft = .action() }
            } label: {
                Image(systemName: "plus")
                    .frame(width: OpsControlMetrics.minimumHitTarget, height: OpsControlMetrics.minimumHitTarget)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel(Text(L10n.text("add", model.language)))
            .help(L10n.text("add", model.language))
        }
        .padding(.horizontal, OpsSpacing.large)
        .padding(.top, OpsSpacing.medium)
        .padding(.bottom, OpsSpacing.small)
    }

    /// 常驻展开（图钉）开关:与条目级置顶(pin/pin.slash)区分,作用于整个 Shelf 窗口。
    /// 关闭时立即收起(Esc 语义之外的显式隐藏);开启后保持当前展开。
    private func toggleKeepOpen() {
        let turningOn = !model.settings.shelfKeepOpen
        model.updateSettings { $0.shelfKeepOpen = turningOn }
        if !turningOn { model.requestHide?() }
    }

    private var search: some View {
        ShelfCommandBar(query: $experience.query, language: model.language, focused: $searchFocused)
            .padding(.horizontal, OpsSpacing.medium)
            .padding(.bottom, OpsSpacing.small)
    }

    private var selectionBar: some View {
        HStack {
            Text("\(L10n.text("selected", model.language)) \(experience.selection.count)")
                .font(OpsTypography.secondaryStrong)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                model.copySelected(using: clipboard)
            } label: { Label(L10n.text("copySelected", model.language), systemImage: "doc.on.doc") }
                .buttonStyle(.borderless)
            OpsIconButton(
                systemName: "trash",
                accessibilityLabel: L10n.text("deleteSelected", model.language),
                destructive: true
            ) {
                model.remove(experience.selection)
            }
            OpsIconButton(
                systemName: "xmark",
                accessibilityLabel: L10n.text("clearSelection", model.language)
            ) {
                experience.selection.removeAll()
            }
        }
        .font(OpsTypography.secondary)
        .padding(.horizontal, OpsSpacing.medium)
        .frame(height: OpsControlMetrics.footerHeight)
        .background(OpsSurface.selectionSubtle(increasedContrast: increasedContrast))
    }

    @ViewBuilder
    private var content: some View {
        let sections = model.quickShelfSnapshot.sections
        let isEmpty = sections.isEmpty

        if isEmpty {
            ShelfEmptyState(filtered: !experience.query.isEmpty || experience.kindFilter != .all, language: model.language)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: OpsSpacing.xSmall) {
                        ForEach(sections) { section in
                            ShelfSectionView(
                                kind: section.kind,
                                language: model.language,
                                count: section.entries.count,
                                action: section.kind == .now || section.kind == .recent
                                    ? L10n.text("clear", model.language) : nil,
                                onAction: section.kind == .now ? model.clearWorkingSet
                                    : section.kind == .recent ? model.clearRecent : nil
                            )
                            ForEach(section.entries) { entry in
                                ShelfEntryRow(model: model, clipboard: clipboard, entry: entry)
                                    .id(entry.id)
                            }
                        }
                    }
                    .padding(.horizontal, OpsSpacing.small)
                    .padding(.vertical, OpsSpacing.small)
                }
                .onChange(of: experience.highlightedQuickEntryID) { id in
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

            if let item = experience.focusedShelfPresentationItem {
                Divider().overlay(OpsSurface.divider(increasedContrast: increasedContrast))
                ShelfInspectorView(item: item, language: model.language,
                                   dispatcher: ShelfItemActionDispatcher(model: model, clipboard: clipboard))
                    .frame(width: OpsControlMetrics.inspectorWidth)
                    .transition(OpsMotion.transition(reduceMotion: reduceMotion))
            }
        }
        .animation(.easeOut(duration: OpsMotion.duration(for: .standard, reduceMotion: reduceMotion)),
                   value: experience.focusedShelfPresentationItem?.id)
    }

    private var footer: some View {
        HStack {
            Text(shortcutHint)
            Spacer()
            Text(contextLabel)
        }
        .font(OpsTypography.metadata)
        .foregroundStyle(.secondary)
        .padding(.horizontal, OpsSpacing.medium)
        .frame(height: OpsControlMetrics.footerHeight)
        .overlay(alignment: .top) {
            if let toast = experience.toast {
                Text(toast)
                    .font(OpsTypography.secondaryStrong)
                    .padding(.horizontal, OpsSpacing.medium)
                    .padding(.vertical, OpsSpacing.xSmall)
                    .background(.regularMaterial, in: Capsule())
                    .offset(y: -OpsControlMetrics.searchHeight)
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

    private var increasedContrast: Bool { colorSchemeContrast == .increased }

    private var contextLabel: String {
        switch experience.appContext {
        case .finder: return L10n.text("shelfContextFinder", model.language)
        case .terminal: return L10n.text("shelfContextTerminal", model.language)
        case .browser: return L10n.text("shelfContextBrowser", model.language)
        case .generic: return L10n.text("unifiedFooter", model.language)
        }
    }

    private var dropView: some View {
        HStack(spacing: OpsSpacing.medium) {
            Image(systemName: "plus.circle.fill")
                .font(OpsTypography.prominentIcon)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: OpsSpacing.xSmall) {
                Text(L10n.text("dropTitle", model.language)).font(OpsTypography.bodyStrong)
                Text(L10n.text("dropHint", model.language)).font(OpsTypography.metadata).foregroundStyle(.secondary)
            }
            Spacer()
            Text(model.settings.addMode == .copy ? L10n.text("dropCopy", model.language) : L10n.text("dropReference", model.language))
                .font(OpsTypography.metadata)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, OpsSpacing.large)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: OpsRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OpsRadius.panel, style: .continuous)
                .strokeBorder(OpsSurface.dropTargetStroke(increasedContrast: increasedContrast), lineWidth: increasedContrast ? 1 : 0.5)
        )
        .padding(OpsSpacing.small)
    }

    private var peekView: some View {
        HStack {
            Image(systemName: "tray.full").foregroundStyle(.secondary)
            Text(L10n.text("quickShelf", model.language)).font(OpsTypography.rowTitle)
            Spacer()
            Text("\(model.visibleItems.count)").font(OpsTypography.metadata).foregroundStyle(.secondary)
        }
        .padding(.horizontal, OpsSpacing.large)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: OpsRadius.card, style: .continuous))
        .padding(OpsSpacing.small)
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
        VStack(alignment: .leading, spacing: OpsSpacing.medium) {
            Text(title).font(.headline)
            TextField(L10n.text("name", model.language), text: $draft.title)
            TextEditor(text: $draft.content)
                .font(OpsTypography.monospacedBody)
                .frame(minHeight: OpsControlMetrics.editorTextMinimumHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: OpsRadius.small)
                        .strokeBorder(.secondary.opacity(0.25))
                )
            if draft.mode == .newAction {
                Picker("", selection: $draft.actionKind) {
                    Text(L10n.text("safePath", model.language)).tag(SafeActionKind.openPath)
                    Text(L10n.text("safeURL", model.language)).tag(SafeActionKind.openURL)
                }.pickerStyle(.segmented)
            }
            if let hint = inlineHint {
                Text(hint)
                    .font(OpsTypography.secondary)
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
        .padding(OpsSpacing.large)
        .frame(width: OpsControlMetrics.editorWidth)
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

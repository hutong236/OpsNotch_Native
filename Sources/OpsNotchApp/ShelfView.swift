#if os(macOS)
import AppKit
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
        // 展开即聚焦(键盘取回流):focusRequestToken 是面板层发来的一次性聚焦请求,
        // 同时把高亮重置到第一行。隐藏面板时令牌被清空,确保每次展开都触发。
        // Tab 重聚焦场景下 SwiftUI 侧 FocusState 可能仍为 true(AppKit field editor 已失焦
        // 但焦点态未同步),直接赋 true 是 no-op——先归 false、下一 runloop 再置 true 强制重聚焦。
        .onReceive(model.$focusRequestToken) { token in
            guard token != nil else { return }
            if searchFocused {
                searchFocused = false
                DispatchQueue.main.async { searchFocused = true }
            } else {
                searchFocused = true
            }
            model.highlightedID = model.visibleItems.first?.id
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
                .focused($searchFocused)
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

    /// 类型筛选 chips:⌘1~⌘5 与之一一对应(见 ShelfWindowController 键盘接管)。
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
        if groups.pinned.isEmpty && groups.recent.isEmpty {
            if model.query.isEmpty && model.kindFilter == .all {
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.system(size: 24, weight: .light)).foregroundStyle(.secondary)
                    Text(L10n.text("empty", model.language)).font(.system(size: 12, weight: .semibold))
                    Text(L10n.text("emptyHint", model.language)).font(.system(size: 10)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(30)
            } else {
                // 有筛选/搜索词时的"无匹配"空态,与真正空柜的引导提示区分。
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
                    // 单个 ForEach 渲染 Pinned+Recent:条目在分区间移动时仍是同一 ForEach 内的
                    // 位置变化,cell 内容会被更新;拆成两个 ForEach 会让 LazyVStack 跨块复用同
                    // id 的旧 cell(保留旧 item 与 hover 状态),置顶后行数据不刷新。
                    LazyVStack(spacing: 3) {
                        ForEach(Array(model.visibleItems.enumerated()), id: \.element.id) { index, item in
                            if index == 0, !groups.pinned.isEmpty {
                                SectionHeader(title: L10n.text("pinned", model.language), count: groups.pinned.count)
                            }
                            if index == groups.pinned.count, !groups.recent.isEmpty {
                                SectionHeader(title: L10n.text("recent", model.language), count: groups.recent.count, action: L10n.text("clear", model.language), onAction: model.clearRecent)
                            }
                            ShelfRowView(model: model, clipboard: clipboard, item: item)
                                .id(item.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                }
                // 键盘高亮变化时只做“确保当前行可见”的最小滚动；不指定 anchor，
                // 避免每按一次方向键都把行强制居中，也不影响鼠标手动滚动。
                // 延后一轮 runloop，可覆盖搜索/类型过滤导致 LazyVStack 同步重建的场景。
                .onChange(of: model.highlightedID) { id in
                    guard let id else { return }
                    DispatchQueue.main.async {
                        proxy.scrollTo(id)
                    }
                }
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
    /// 键盘流高亮(单一当前行),与多选 selection 的蓝底样式区分。
    private var highlighted: Bool { model.highlightedID == item.id }

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
        .padding(.horizontal, 8)
        .frame(height: 42)
        .background(selected ? Color.accentColor.opacity(0.12) : hovered ? Color.primary.opacity(0.055) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            if highlighted && !selected {
                // 白描边 + 浅底:键盘流“当前行”指示,与多选蓝底、悬停灰底都不同。
                // 必须 allowsHitTesting(false):overlay 在行内容之上,否则浅底
                // 会拦截整行点击(高亮默认落在第一行,首行按钮/单击全部失效)。
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.white.opacity(0.55), lineWidth: 1)
                    .background(Color.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        // 仅为右键菜单提供整行命中区域;单击手势只挂在 leading 上,
        // 避免与悬停操作按钮发生手势仲裁(行级单击会把按钮点击抢成默认动作)。
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .contextMenu {
            if item.kind == .text || item.kind == .url {
                Button(L10n.text("copy", model.language)) {
                    clipboard.copyFromApp(item.content)
                    model.touchItem(item.id)
                    model.showToast(L10n.text("copied", model.language))
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
            Button(item.pinned ? L10n.text("unpin", model.language) : L10n.text("pin", model.language)) { model.togglePin(item) }
            Button(L10n.text("edit", model.language)) { model.beginEdit(item) }
            Button(L10n.text("remove", model.language), role: .destructive) { model.remove(Set([item.id])) }
        }
    }

    /// 左侧图标 + 标题/副标题:行的单击(默认动作/多选)只挂在这里,
    /// 与行尾悬停按钮隔离,按钮点击不再被行级手势抢占。
    private var leading: some View {
        HStack(spacing: 8) {
            itemIcon
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                Text(subtitle).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
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
        if let icon = ItemActionService.icon(for: item) {
            Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: symbolName).font(.system(size: 15)).foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 7) {
            if item.kind == .text || item.kind == .url {
                actionIcon("doc.on.doc") {
                    clipboard.copyFromApp(item.content)
                    model.touchItem(item.id)
                    model.showToast(L10n.text("copied", model.language))
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
            actionIcon(item.pinned ? "pin.slash" : "pin") { model.togglePin(item) }
        }
        .foregroundStyle(.secondary)
        .font(.system(size: 11))
    }

    /// 行内操作按钮不用 Button:懒加载栈里行级手势与 Button 的仲裁在部分
    /// macOS 版本上会把按钮点击抢成默认动作;图标 + onTapGesture 是最深层
    /// 手势,必胜且无仲裁环节。也不要加 .help(会包 accessory 视图影响命中)。
    private func actionIcon(_ symbol: String, action: @escaping () -> Void) -> some View {
        Image(systemName: symbol)
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
            .onTapGesture { action() }
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
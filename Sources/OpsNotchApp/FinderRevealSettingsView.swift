#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

struct FinderRevealSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controller: FinderRevealController
    @AppStorage(FinderOpenModePreference.key) private var finderOpenModeRaw = FinderOpenMode.systemDefault.rawValue

    var body: some View {
        VStack(spacing: OpsSpacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: OpsSpacing.micro) {
                    Text(model.language == .zhCN ? "Finder 兼容快捷键" : "Finder compatibility hotkey")
                        .font(OpsTypography.body)
                    Text(model.language == .zhCN
                         ? "可选：与主快捷键打开同一个 Quick Shelf，并直接定位默认目录。"
                         : "Optional: opens the same Quick Shelf as the main hotkey and focuses the default folder.")
                        .font(OpsTypography.metadata)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                FinderRevealHotkeyRecorderView(model: model, controller: controller)
            }

            Divider()

            HStack {
                Text(model.language == .zhCN ? "默认路径" : "Default path")
                    .font(OpsTypography.body)
                Spacer()
                TextField("~", text: defaultPathBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: OpsControlMetrics.settingsDefaultPathFieldWidth)
                Button(model.language == .zhCN ? "选择…" : "Choose…") { chooseDefaultFolder() }
            }

            Divider()

            HStack {
                Text(model.language == .zhCN ? "Finder 打开方式" : "Finder open mode")
                    .font(OpsTypography.body)
                Spacer()
                Picker("", selection: $finderOpenModeRaw) {
                    Text(model.language == .zhCN ? "系统默认（推荐）" : "System default (recommended)")
                        .tag(FinderOpenMode.systemDefault.rawValue)
                    Text(model.language == .zhCN ? "优先在现有 Finder 新建 Tab" : "Prefer a new tab in existing Finder")
                        .tag(FinderOpenMode.preferTab.rawValue)
                }
                .labelsHidden()
                .frame(width: OpsControlMetrics.settingsFinderModePickerWidth)
            }

            Text(model.language == .zhCN
                 ? "系统默认会立即打开目录，不运行 Finder 自动化，速度最快且稳定性最高。“优先 Tab”仅在你主动选择时启用：一次自动化调用内先复用已有目标目录，否则尝试新建 Tab；失败或权限不足时自动回退。"
                 : "System default opens the folder immediately without Finder automation for the fastest, most reliable response. Prefer Tab runs only when explicitly selected: one automation call reuses an existing target or attempts a new tab, with a safe fallback on failure or missing permission.")
                .font(OpsTypography.secondary)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: OpsSpacing.small) {
                HStack {
                    Text(model.language == .zhCN ? "收藏目录" : "Favorite folders")
                        .font(OpsTypography.bodyStrong)
                    Spacer()
                    Button(model.language == .zhCN ? "添加目录" : "Add Folder") { addFavorite() }
                        .disabled(model.settings.finderQuickPaths.count >= 9)
                }

                ForEach(Array(model.settings.finderQuickPaths.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: OpsSpacing.small) {
                        Text("\(index + 1)")
                            .font(OpsTypography.rowTitle)
                            .frame(
                                width: OpsControlMetrics.settingsSlotBadgeSize,
                                height: OpsControlMetrics.settingsSlotBadgeSize
                            )
                            .background(
                                OpsSurface.card,
                                in: RoundedRectangle(cornerRadius: OpsRadius.small, style: .continuous)
                            )

                        TextField(model.language == .zhCN ? "名称" : "Label", text: labelBinding(for: item.id))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: OpsControlMetrics.settingsFinderLabelFieldWidth)

                        TextField("/path/to/folder", text: pathBinding(for: item.id))
                            .textFieldStyle(.roundedBorder)

                        Button(model.language == .zhCN ? "选择…" : "Choose…") { chooseFolder(for: item.id) }
                        Button(role: .destructive) { remove(item.id) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                    }
                }

                if model.settings.finderQuickPaths.isEmpty {
                    Text(model.language == .zhCN
                         ? "未收藏目录。添加后会出现在统一 Quick Shelf 的 Finder 分区。"
                         : "No favorites yet. Added folders appear in the Finder section of the unified Quick Shelf.")
                        .font(OpsTypography.secondary)
                        .foregroundStyle(.secondary)
                }
            }

            Text(model.language == .zhCN
                 ? "默认路径始终位于统一 Quick Shelf 的 Finder 分区首行；收藏目录按最近使用和使用频率自动靠前。使用主 Quick Shelf 快捷键即可同时搜索目录、文件和剪贴板内容；这里的 Finder 快捷键仅作为老用户兼容入口。"
                 : "The default folder is always first in the Finder section of the unified Quick Shelf; favorites move up by recent and frequent use. The main Quick Shelf hotkey searches folders, files, and clipboard content together; this Finder hotkey remains only as a compatibility shortcut.")
                .font(OpsTypography.secondary)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var defaultPathBinding: Binding<String> {
        Binding(
            get: { model.settings.finderDefaultPath },
            set: { value in model.updateSettings { $0.finderDefaultPath = value } }
        )
    }

    private func labelBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { model.settings.finderQuickPaths.first(where: { $0.id == id })?.label ?? "" },
            set: { value in
                model.updateSettings { settings in
                    guard let index = settings.finderQuickPaths.firstIndex(where: { $0.id == id }) else { return }
                    settings.finderQuickPaths[index].label = value
                }
            }
        )
    }

    private func pathBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { model.settings.finderQuickPaths.first(where: { $0.id == id })?.path ?? "" },
            set: { value in
                model.updateSettings { settings in
                    guard let index = settings.finderQuickPaths.firstIndex(where: { $0.id == id }) else { return }
                    settings.finderQuickPaths[index].path = value
                }
            }
        )
    }

    private func chooseDefaultFolder() {
        guard let url = chooseDirectory() else { return }
        model.updateSettings { $0.finderDefaultPath = url.path }
    }

    private func addFavorite() {
        guard model.settings.finderQuickPaths.count < 9, let url = chooseDirectory() else { return }
        let label = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        model.updateSettings { settings in
            settings.finderQuickPaths.append(FinderQuickPath(label: label, path: url.path))
        }
    }

    private func chooseFolder(for id: UUID) {
        guard let url = chooseDirectory() else { return }
        model.updateSettings { settings in
            guard let index = settings.finderQuickPaths.firstIndex(where: { $0.id == id }) else { return }
            settings.finderQuickPaths[index].path = url.path
            if settings.finderQuickPaths[index].label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                settings.finderQuickPaths[index].label = url.lastPathComponent
            }
        }
    }

    private func remove(_ id: UUID) {
        model.updateSettings { settings in
            settings.finderQuickPaths.removeAll { $0.id == id }
        }
    }

    private func chooseDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.directoryURL = URL(fileURLWithPath: NSString(string: model.settings.finderDefaultPath).expandingTildeInPath, isDirectory: true)
        return panel.runModal() == .OK ? panel.url : nil
    }
}

private struct FinderRevealHotkeyRecorderView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controller: FinderRevealController
    @State private var recording = false
    @State private var invalidHint = false
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var increasedContrast: Bool { colorSchemeContrast == .increased }

    var body: some View {
        VStack(alignment: .trailing, spacing: OpsSpacing.xSmall) {
            if recording {
                FinderRevealHotkeyCaptureField(
                    onShortcut: { shortcut in
                        invalidHint = false
                        recording = false
                        controller.setHotkey(shortcut)
                    },
                    onClear: {
                        invalidHint = false
                        recording = false
                        controller.setHotkey(nil)
                    },
                    onInvalid: { invalidHint = true },
                    onCancel: { recording = false; invalidHint = false }
                )
                .frame(
                    width: OpsControlMetrics.settingsHotkeyRecorderWidth,
                    height: OpsControlMetrics.minimumHitTarget
                )
                .background(
                    OpsSurface.hover,
                    in: RoundedRectangle(cornerRadius: OpsRadius.small, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OpsRadius.small, style: .continuous)
                        .strokeBorder(
                            OpsSurface.focusStroke(increasedContrast: increasedContrast),
                            lineWidth: increasedContrast ? 1.5 : 1
                        )
                )
                .overlay(
                    Text(L10n.text("hotkeyRecording", model.language))
                        .font(OpsTypography.body)
                        .foregroundStyle(.secondary)
                        .allowsHitTesting(false)
                )
            } else {
                Button {
                    invalidHint = false
                    controller.clearConflict()
                    recording = true
                } label: {
                    HStack(spacing: OpsSpacing.small) {
                        Text(currentText).font(OpsTypography.body)
                        if model.settings.finderRevealHotkey != nil {
                            Text(L10n.text("hotkeyRerecordHint", model.language))
                                .font(OpsTypography.metadata)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, OpsSpacing.medium)
                    .frame(
                        width: OpsControlMetrics.settingsHotkeyRecorderWidth,
                        height: OpsControlMetrics.minimumHitTarget
                    )
                    .background(
                        OpsSurface.hover,
                        in: RoundedRectangle(cornerRadius: OpsRadius.small, style: .continuous)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if invalidHint {
                Text(L10n.text("hotkeyInvalid", model.language))
                    .font(OpsTypography.secondary)
                    .foregroundStyle(.red)
            }
            if controller.hotkeyConflict {
                Text(L10n.text("hotkeyConflict", model.language))
                    .font(OpsTypography.secondary)
                    .foregroundStyle(.red)
            }
        }
    }

    private var currentText: String {
        if let hotkey = model.settings.finderRevealHotkey { return HotkeyDisplay.text(hotkey) }
        return L10n.text("hotkeyNone", model.language)
    }
}

private final class FinderRevealHotkeyCaptureView: NSView {
    var onShortcut: ((HotkeyShortcut) -> Void)?
    var onClear: (() -> Void)?
    var onInvalid: (() -> Void)?
    var onCancel: (() -> Void)?
    private var focusRequested = false

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window, !focusRequested {
            focusRequested = true
            window.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onCancel?()
        case 51 where event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.numericPad).isEmpty: onClear?()
        default:
            if let shortcut = HotkeyEventMapper.shortcut(from: event) { onShortcut?(shortcut) }
            else { onInvalid?() }
        }
    }
}

private struct FinderRevealHotkeyCaptureField: NSViewRepresentable {
    let onShortcut: (HotkeyShortcut) -> Void
    let onClear: () -> Void
    let onInvalid: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> FinderRevealHotkeyCaptureView {
        let view = FinderRevealHotkeyCaptureView()
        view.onShortcut = onShortcut
        view.onClear = onClear
        view.onInvalid = onInvalid
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: FinderRevealHotkeyCaptureView, context: Context) {}
}
#endif

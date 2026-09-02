#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

struct FinderRevealSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controller: FinderRevealController
    @AppStorage(FinderOpenModePreference.key) private var finderOpenModeRaw = FinderOpenMode.systemDefault.rawValue

    var body: some View {
        VStack(spacing: 11) {
            HStack {
                Text(model.language == .zhCN ? "快捷路径快捷键" : "Quick path hotkey")
                    .font(.system(size: 12))
                Spacer()
                FinderRevealHotkeyRecorderView(model: model, controller: controller)
            }

            Divider()

            HStack {
                Text(model.language == .zhCN ? "默认路径" : "Default path")
                    .font(.system(size: 12))
                Spacer()
                TextField("~", text: defaultPathBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 245)
                Button(model.language == .zhCN ? "选择…" : "Choose…") { chooseDefaultFolder() }
            }

            Divider()

            HStack {
                Text(model.language == .zhCN ? "Finder 打开方式" : "Finder open mode")
                    .font(.system(size: 12))
                Spacer()
                Picker("", selection: $finderOpenModeRaw) {
                    Text(model.language == .zhCN ? "系统默认（推荐）" : "System default (recommended)")
                        .tag(FinderOpenMode.systemDefault.rawValue)
                    Text(model.language == .zhCN ? "优先在现有 Finder 新建 Tab" : "Prefer a new tab in existing Finder")
                        .tag(FinderOpenMode.preferTab.rawValue)
                }
                .labelsHidden()
                .frame(width: 285)
            }

            Text(model.language == .zhCN
                 ? "系统默认会立即打开目录，不运行 Finder 自动化，速度最快且稳定性最高。“优先 Tab”仅在你主动选择时启用：一次自动化调用内先复用已有目标目录，否则尝试新建 Tab；失败或权限不足时自动回退。"
                 : "System default opens the folder immediately without Finder automation for the fastest, most reliable response. Prefer Tab runs only when explicitly selected: one automation call reuses an existing target or attempts a new tab, with a safe fallback on failure or missing permission.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(model.language == .zhCN ? "收藏目录（数字 1–9）" : "Favorite folders (1–9)")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button(model.language == .zhCN ? "添加目录" : "Add Folder") { addFavorite() }
                        .disabled(model.settings.finderQuickPaths.count >= 9)
                }

                ForEach(Array(model.settings.finderQuickPaths.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .frame(width: 24, height: 24)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

                        TextField(model.language == .zhCN ? "名称" : "Label", text: labelBinding(for: item.id))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 105)

                        TextField("/path/to/folder", text: pathBinding(for: item.id))
                            .textFieldStyle(.roundedBorder)

                        Button(model.language == .zhCN ? "选择…" : "Choose…") { chooseFolder(for: item.id) }
                        Button(role: .destructive) { remove(item.id) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                    }
                }

                if model.settings.finderQuickPaths.isEmpty {
                    Text(model.language == .zhCN
                         ? "未收藏目录。添加后可在启动器中按数字键直接打开。"
                         : "No favorites yet. Add folders to open them directly with number keys.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Text(model.language == .zhCN
                 ? "快捷键弹出路径面板；默认路径始终在首行。收藏目录会按最近使用和使用频率自动靠前，但数字 1–9 的绑定始终固定不变。↑↓选择，回车打开当前项；直接回车打开默认路径。“优先 Tab”模式会先激活已有的同路径窗口。"
                 : "The hotkey opens a path panel with the default path always first. Favorites are visually reordered by recent and frequent use, while number bindings 1–9 never change. Use ↑↓ and Return, or press Return immediately for the default path. Prefer Tab first activates an existing Finder window for the same path.")
                .font(.system(size: 10))
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

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
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
                .frame(width: 190, height: 28)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1))
                .overlay(
                    Text(L10n.text("hotkeyRecording", model.language))
                        .font(.system(size: 11)).foregroundStyle(.secondary).allowsHitTesting(false)
                )
            } else {
                Button {
                    invalidHint = false
                    controller.clearConflict()
                    recording = true
                } label: {
                    HStack(spacing: 6) {
                        Text(currentText).font(.system(size: 11))
                        if model.settings.finderRevealHotkey != nil {
                            Text(L10n.text("hotkeyRerecordHint", model.language))
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(width: 190, height: 28)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if invalidHint {
                Text(L10n.text("hotkeyInvalid", model.language)).font(.system(size: 10)).foregroundStyle(.red)
            }
            if controller.hotkeyConflict {
                Text(L10n.text("hotkeyConflict", model.language)).font(.system(size: 10)).foregroundStyle(.red)
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

#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

struct FinderRevealSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controller: FinderRevealController

    var body: some View {
        VStack(spacing: 11) {
            HStack {
                Text(model.language == .zhCN ? "目标应用" : "Target application").font(.system(size: 12))
                Spacer()
                TextField("gf.app", text: appNameBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 190)
            }
            Divider()
            HStack {
                Text(model.language == .zhCN ? "Finder 定位快捷键" : "Finder reveal hotkey").font(.system(size: 12))
                Spacer()
                FinderRevealHotkeyRecorderView(model: model, controller: controller)
            }
            Text(model.language == .zhCN
                 ? "在任意应用中按下快捷键，使用 Spotlight 查找目标 .app，并在 Finder 中直接选中；不会启动应用。"
                 : "Press the hotkey in any app to find the target .app with Spotlight and select it in Finder without launching it.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var appNameBinding: Binding<String> {
        Binding(
            get: { model.settings.finderRevealAppName },
            set: { value in model.updateSettings { $0.finderRevealAppName = value } }
        )
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

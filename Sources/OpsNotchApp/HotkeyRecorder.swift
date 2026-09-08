#if os(macOS)
import AppKit
import SwiftUI
import OpsNotchCore

/// 快捷键的人类可读渲染(⌃⌥⇧⌘ + 键名),仅用于界面显示。
enum HotkeyDisplay {
    static func text(_ shortcut: HotkeyShortcut) -> String {
        var glyphs = ""
        let modifiers = shortcut.carbonModifiers
        if modifiers & HotkeyValidation.carbonControl != 0 { glyphs += "⌃" }
        if modifiers & HotkeyValidation.carbonOption != 0 { glyphs += "⌥" }
        if modifiers & HotkeyValidation.carbonShift != 0 { glyphs += "⇧" }
        if modifiers & HotkeyValidation.carbonCommand != 0 { glyphs += "⌘" }
        return glyphs + keyName(shortcut.keyCode)
    }

    /// 虚拟键码 → 键名。覆盖常用键,未收录的键回退为 "Key <code>"。
    static func keyName(_ code: UInt32) -> String {
        let letters: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M"
        ]
        if let letter = letters[code] { return letter }
        let others: [UInt32: String] = [
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
            24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\", 43: ",", 44: "/", 47: ".",
            49: "Space", 123: "←", 124: "→", 125: "↓", 126: "↑", 51: "⌫", 48: "Tab", 36: "↩"
        ]
        return others[code] ?? "Key \(code)"
    }
}

/// 录制态的键捕获视图:成为 first responder 后拦截 keyDown——合法组合提交、
/// Esc 取消、⌫ 清除、非法组合提示。视觉完全交给外层 SwiftUI。
private final class HotkeyCaptureView: NSView {
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
        case 53: // Esc
            onCancel?()
        case 51 where event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.numericPad).isEmpty: // ⌫ 清除
            onClear?()
        default:
            if let shortcut = HotkeyEventMapper.shortcut(from: event) {
                onShortcut?(shortcut)
            } else {
                onInvalid?()
            }
        }
    }
}

/// 可复用的 Carbon 热键录制控件。Quick Shelf 与菜单栏管理共享同一交互，不共享注册 ID。
struct HotkeyRecorderControl: View {
    let language: AppLanguage
    let shortcut: HotkeyShortcut?
    let conflict: Bool
    var onPrepare: () -> Void = {}
    let onSet: (HotkeyShortcut?) -> Void

    @State private var recording = false
    @State private var invalidHint = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            recorder
            if invalidHint {
                Text(L10n.text("hotkeyInvalid", language))
                    .font(.system(size: 10)).foregroundStyle(.red)
            }
            if conflict {
                Text(L10n.text("hotkeyConflict", language))
                    .font(.system(size: 10)).foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder private var recorder: some View {
        if recording {
            HotkeyCaptureField(
                onShortcut: { value in
                    invalidHint = false
                    recording = false
                    onSet(value)
                },
                onClear: {
                    invalidHint = false
                    recording = false
                    onSet(nil)
                },
                onInvalid: { invalidHint = true },
                onCancel: { recording = false; invalidHint = false }
            )
            .frame(width: 190, height: 28)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1)
            )
            .overlay(
                Text(L10n.text("hotkeyRecording", language))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            )
        } else {
            Button {
                invalidHint = false
                onPrepare()
                recording = true
            } label: {
                HStack(spacing: 6) {
                    Text(currentText).font(.system(size: 11))
                    if shortcut != nil {
                        Text(L10n.text("hotkeyRerecordHint", language))
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
    }

    private var currentText: String {
        if let shortcut { return HotkeyDisplay.text(shortcut) }
        return L10n.text("hotkeyNone", language)
    }
}

struct HotkeyRecorderView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HotkeyRecorderControl(
            language: model.language,
            shortcut: model.settings.hotkey,
            conflict: model.hotkeyConflict,
            onPrepare: { model.hotkeyConflict = false },
            onSet: { model.setHotkey($0) }
        )
    }
}

private struct HotkeyCaptureField: NSViewRepresentable {
    let onShortcut: (HotkeyShortcut) -> Void
    let onClear: () -> Void
    let onInvalid: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> HotkeyCaptureView {
        let view = HotkeyCaptureView()
        view.onShortcut = onShortcut
        view.onClear = onClear
        view.onInvalid = onInvalid
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: HotkeyCaptureView, context: Context) {}
}
#endif

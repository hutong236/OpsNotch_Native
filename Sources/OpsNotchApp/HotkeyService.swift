#if os(macOS)
import AppKit
import Carbon
import OpsNotchCore

/// 全局呼出热键抽象。实现后端可替换(当前为 Carbon 注册式热键:零权限、注册即独占消费按键,
/// 不会穿透前台应用),持久化的 HotkeyShortcut 模型与后端无关,换后端不需要用户重录。
@MainActor
protocol HotkeyService: AnyObject {
    /// 应用新的快捷键,nil 表示注销。返回 nil 表示成功;注册失败(如组合键被占用)时
    /// 自动回滚到原快捷键并返回错误。
    @discardableResult
    func apply(_ shortcut: HotkeyShortcut?) -> HotkeyError?
    var onFire: (() -> Void)? { get set }
}

enum HotkeyError: LocalizedError {
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status): return "Hotkey registration failed (\(status))."
        }
    }
}

@MainActor
final class CarbonHotkeyService: HotkeyService {
    var onFire: (() -> Void)?

    private var current: HotkeyShortcut?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// 'opsn' — 本应用热键 ID 的 OSType 签名。
    private static let signature: OSType = 0x6F70736E
    private static let hotKeyID = EventHotKeyID(signature: signature, id: 1)

    @discardableResult
    func apply(_ shortcut: HotkeyShortcut?) -> HotkeyError? {
        unregisterCurrent()
        guard let shortcut else {
            current = nil
            return nil
        }
        if let error = register(shortcut) {
            // 回滚:尽力恢复原快捷键,保证界面显示与实际注册状态一致。
            if let previous = current { _ = register(previous) }
            return error
        }
        current = shortcut
        return nil
    }

    private func register(_ shortcut: HotkeyShortcut) -> HotkeyError? {
        installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            Self.hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return .registrationFailed(status) }
        hotKeyRef = ref
        return nil
    }

    private func unregisterCurrent() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<CarbonHotkeyService>.fromOpaque(userData).takeUnretainedValue()
            // Carbon 事件在主线程派发,回调跳到 MainActor 域再触发业务逻辑。
            DispatchQueue.main.async { MainActor.assumeIsolated { service.onFire?() } }
            return noErr
        }, 1, &spec, selfPointer, &handlerRef)
    }
}

/// 把 NSEvent 的一次按键转换为后端无关的 HotkeyShortcut;不合法组合返回 nil。
@MainActor
enum HotkeyEventMapper {
    static func shortcut(from event: NSEvent) -> HotkeyShortcut? {
        var carbon: UInt32 = 0
        let flags = event.modifierFlags
        if flags.contains(.command) { carbon |= HotkeyValidation.carbonCommand }
        if flags.contains(.shift) { carbon |= HotkeyValidation.carbonShift }
        if flags.contains(.option) { carbon |= HotkeyValidation.carbonOption }
        if flags.contains(.control) { carbon |= HotkeyValidation.carbonControl }
        let shortcut = HotkeyShortcut(keyCode: UInt32(event.keyCode), carbonModifiers: carbon)
        return HotkeyValidation.isAcceptable(shortcut) ? shortcut : nil
    }
}
#endif

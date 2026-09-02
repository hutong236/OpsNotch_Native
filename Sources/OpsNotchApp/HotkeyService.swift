#if os(macOS)
import AppKit
import Carbon
import OpsNotchCore

/// 全局热键抽象。实现后端可替换(当前为 Carbon 注册式热键:零权限、注册即独占消费按键,
/// 不会穿透前台应用),持久化的 HotkeyShortcut 模型与后端无关,换后端不需要用户重录。
@MainActor
protocol HotkeyService: AnyObject {
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
    private let hotKeyID: EventHotKeyID

    private static let signature: OSType = 0x6F70736E // 'opsn'

    init(id: UInt32 = 1) {
        hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
    }

    @discardableResult
    func apply(_ shortcut: HotkeyShortcut?) -> HotkeyError? {
        let previous = current
        unregisterCurrent()
        guard let shortcut else {
            current = nil
            return nil
        }
        if let error = register(shortcut) {
            if let previous { _ = register(previous) }
            current = previous
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
            hotKeyID,
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
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<CarbonHotkeyService>.fromOpaque(userData).takeUnretainedValue()

            var pressedID = EventHotKeyID(signature: 0, id: 0)
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &pressedID
            )
            guard status == noErr,
                  pressedID.signature == service.hotKeyID.signature,
                  pressedID.id == service.hotKeyID.id else {
                return OSStatus(eventNotHandledErr)
            }

            DispatchQueue.main.async { MainActor.assumeIsolated { service.onFire?() } }
            return noErr
        }, 1, &spec, selfPointer, &handlerRef)
    }
}

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

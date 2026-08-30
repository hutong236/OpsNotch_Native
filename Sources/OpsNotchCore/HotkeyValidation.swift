import Foundation

/// 全局呼出热键的合法性校验,纯函数、与 UI 及注册后端无关。
/// 修饰键位值与 Carbon Events.h 一致(cmd=0x0100, shift=0x0200, option=0x0800, control=0x1000),
/// 在这里以字面量定义,保持 Core 只依赖 Foundation。
public enum HotkeyValidation {
    public static let carbonCommand: UInt32 = 0x0100
    public static let carbonShift: UInt32 = 0x0200
    public static let carbonOption: UInt32 = 0x0800
    public static let carbonControl: UInt32 = 0x1000

    /// 修饰键自身的虚拟键码(左右 ⌘/⇧/⌥/⌃ 及 fn),按下的“普通键”不允许是它们。
    private static let modifierKeyCodes: Set<UInt32> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    /// 可注册的组合:至少含 ⌘/⌥/⌃ 之一(仅 ⇧ 太容易误触),且主键不是修饰键本身。
    public static func isAcceptable(keyCode: UInt32, carbonModifiers: UInt32) -> Bool {
        let strongModifiers = carbonModifiers & (carbonCommand | carbonOption | carbonControl)
        guard strongModifiers != 0 else { return false }
        guard !modifierKeyCodes.contains(keyCode) else { return false }
        return true
    }

    public static func isAcceptable(_ shortcut: HotkeyShortcut) -> Bool {
        isAcceptable(keyCode: shortcut.keyCode, carbonModifiers: shortcut.carbonModifiers)
    }
}

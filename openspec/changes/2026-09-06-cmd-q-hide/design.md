# Design: ⌘Q 隐藏而非退出

## 方案

在 `OpsNotchNativeApp` 的 SwiftUI `commands` 中替换系统默认 `.appTermination` 命令组：

- 提供一个带 `⌘Q` 快捷键的“隐藏 Ops Notch”命令。
- 命令执行 `NSApplication.shared.hide(nil)`。
- `StatusBarController` 中现有“退出”动作保持 `NSApplication.shared.terminate(nil)`，作为唯一应用内显式退出入口。

## 为什么不使用 applicationShouldTerminate 全局拦截

如果在 `NSApplicationDelegate.applicationShouldTerminate` 中无条件取消终止并隐藏，除了 `⌘Q` 外还可能拦截系统注销/关机等正常终止请求。命令层替换只改变用户按下 `⌘Q` 时的行为，不改变系统生命周期语义。

## 生命周期

`hide(nil)` 只隐藏应用界面，不销毁 AppDelegate、状态栏项、ClipboardManager、HotkeyService 等常驻对象，因此后台能力保持运行。

## 兼容性

`CommandGroup(replacing: .appTermination)` 和 SwiftUI Commands 可用于项目最低支持版本 macOS 13，无需新增权限或第三方依赖。

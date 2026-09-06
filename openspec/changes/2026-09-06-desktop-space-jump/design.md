# Design: 快速桌面跳转

## 命令层
`DesktopCommandParser` 位于 `OpsNotchCore`，只负责纯文本解析：
- `d1` / `desktop 1` / `桌面 1` -> 指定桌面
- `d` / `desktop` / `桌面` -> 桌面列表

`DesktopCommandIntegration` 监听统一搜索词并做短防抖。明确桌面命令直接执行，不增加新的系统级快捷键。

## Space 拓扑
`DesktopSpaceController` 动态加载 SkyLight，只读调用 `SLSCopyManagedDisplaySpaces`，读取：显示器标识、当前 Space、Space 顺序、ManagedSpaceID 和类型。每次执行重新读取，因此显示器插拔或 Mission Control 重排后无需缓存刷新。

桌面编号按 `NSScreen.screens` 的显示器顺序，再按各显示器 Space 顺序生成全局 `d1...dn`。

## 切换后端
1. macOS 26 及以前：默认发送 DockControl/DockSwipe 高速度原生手势事件。
2. 若目标 Space 未确认切换成功，或运行在 macOS 27：使用 `hidSystemState` + `kCGHIDEventTap` 发送 Control+左右方向键作为 fallback。
3. 每次切换都通过重新读取目标显示器 Current Space 进行确认，失败则恢复原鼠标位置并提示。

不使用 `CGSManagedDisplaySetCurrentSpace` 作为主写路径。

## 焦点与鼠标
- 离开一个 Space 时记录其 Quartz 鼠标坐标和前台应用 PID。
- 切换前将鼠标 warp 到目标显示器，使 Dock 将手势路由到正确显示器。
- 完成后优先恢复该 Space 上次鼠标位置，否则放到目标显示器中心。
- 从目标显示器当前可见 Layer-0 窗口中选择首选窗口，使用 `NSRunningApplication.activate` 与 AX Raise 恢复操作焦点。

## 权限与降级
- 仅申请 Accessibility。
- SkyLight API 动态解析；不可用时返回可见错误，不崩溃。
- 不关闭 SIP、不做代码注入。

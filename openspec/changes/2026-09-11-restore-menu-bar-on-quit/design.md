# Design: 退出恢复菜单栏

## 方案

应用终止由 `AppDelegate.applicationShouldTerminate` 统一拦截一次：

1. 记录当前 `menuBarLastState`。
2. 调用 `MenuBarManager.showAll()`，立即把普通隐藏区和持续隐藏区的 Spacer 恢复为展开几何，并关闭隐藏图标代理面板。
3. 将 `menuBarLastState` 写回终止前的值，确保此次恢复只影响当前运行期。
4. 返回 `.terminateLater`，把真正终止延后到主线程下一轮 runloop，让 AppKit 有机会先完成菜单栏重新布局。
5. 在 `applicationWillTerminate` 再执行一次幂等恢复兜底，然后停止菜单栏管理、拖拽与剪贴板监听。

## 为什么放在 AppDelegate

如果只在状态栏“退出”按钮里处理，只能覆盖这一条入口；注销、关机或其他正常终止请求可能绕过该按钮。放在应用级终止委托可以覆盖所有正常 termination 请求，同时不影响现有 SwiftUI 对 `⌘Q` 的替换逻辑。

## 偏好保护

`showAll()` 是现有用户动作 API，会持久化 `allExpanded`。终止保护调用后立即恢复进入终止流程前的 `menuBarLastState`，且使用 `notifyServices: false`，避免退出阶段再次触发 Sensor、热键、Finder 或菜单栏同步。

## 幂等

使用 `terminationRestorePrepared` 防止恢复逻辑在 `applicationShouldTerminate` 与 `applicationWillTerminate` 中重复执行；使用 `terminationReplyPending` 防止短时间内重复终止请求导致多次 reply。

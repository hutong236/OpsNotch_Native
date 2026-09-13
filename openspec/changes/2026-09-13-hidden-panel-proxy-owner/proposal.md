# 隐藏图标跨进程原生窗口路由

## 问题

PR #103 后，用户在 macOS 26.6.2 的实机诊断显示 WindowServer 菜单栏清单读取正常，但 AX 菜单项所属 PID 与真实 status-window owner PID 不一致：AX 为 `pid=75732 frame=(-3016,3,38,24)`，唯一几何匹配的原生窗口为 `window=7619 pid=1284 layer=25 frame=(-3015,0,36,30)`。现有 resolver 强制 `window.pid == AX pid`，因此在已经找到真实窗口后仍拒绝投递。

## 改动

- 保留 AX window ID、公共窗口和同 PID WindowServer 匹配的现有优先级。
- 仅当 AX 没有 authoritative window ID、同 PID 没有任何几何匹配的 status-window、并且 WindowServer 菜单栏清单中恰好只有一个跨 PID status-window 包含 AX 矩形时，接受该窗口作为代理目标。
- 目标 PID 使用真实原生窗口 owner PID，后续事件编码、`postToPid` 和投递前复核均以该 PID 与 Window ID 为准。
- 多个跨 PID 候选、同 PID 候选存在歧义、非 status-window 或失效 AX window ID 均继续拒绝。

## 验证

将用户实机的 `75732 -> 1284 / window 7619` 几何数据加入原生点击探针，检查解析后的目标 PID、Window ID、局部坐标和事件 target PID；同时覆盖跨 PID 候选歧义、非 status-window 及 stale AX window ID。真实第三方状态项仍需用户会话验收。

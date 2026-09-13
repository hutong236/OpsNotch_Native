# Tasks

- [x] 用用户实机日志确认 WindowServer 清单可读但 AX PID 与原生 status-window owner PID 不一致。
- [x] 保留同 PID 优先级并增加受限跨 PID WindowServer fallback。
- [x] 将事件目标 PID 改为真实原生窗口 owner，并沿用同源投递前复核。
- [x] 阻止 authoritative AX window ID、同 owner 歧义、跨 owner 歧义和非 status-window 进入 fallback。
- [x] 将 `75732 -> 1284 / window 7619` 几何及事件 PID 写入原生点击回归。
- [ ] macOS 26 CI：原生点击探针、Core tests、Debug/Release 构建、静态检查和打包。
- [ ] 用户真机：持续隐藏区第三方图标左键、右键、菜单选项，确认不展开隐藏区域。

# 设计

- `Target.pid` 明确定义为原生目标窗口 owner PID，而不是 AX 元素 PID。正常同进程场景两者相同；代理场景可不同。
- resolver 顺序保持：AX window ID 定向查询 → 同 PID 公共窗口 → 同 PID WindowServer 菜单栏窗口 → 受限跨 PID fallback。
- 跨 PID fallback 只在 `axWindow == nil` 时启用。若 AX 已提供窗口编号，即使编号失效也不得改选其他窗口。
- 在进入跨 PID fallback 前，先统计同 AX PID、`statusWindow` 层级且包含 AX 矩形的 WindowServer 候选。只有候选数为 0 才继续；候选数大于 1 视为同 owner 歧义并停止。
- 跨 PID 候选必须来自 WindowServer 专用菜单栏清单、真实 owner PID 与 AX PID 不同、`layer == statusWindow`、窗口 ID/矩形有效且以 1pt 容差包含 AX 矩形。只接受唯一候选，不做距离排序或 first-match。
- 成功后保存真实窗口 PID、Window ID、frame、source 和 AX 中心对应的窗口内坐标。`currentTarget` 继续通过 WindowServer 按同一 Window ID 复核 owner PID 和尺寸；事件的 target PID 以及 `postToPid` 都使用真实窗口 PID。
- 诊断成功路径区分 `server-window` 与 `server-proxy-window`，记录 `ax-pid` / `window-pid`；失败路径增加同 owner 候选数与 proxy 候选数，便于区分缺失、歧义和 owner 代理。

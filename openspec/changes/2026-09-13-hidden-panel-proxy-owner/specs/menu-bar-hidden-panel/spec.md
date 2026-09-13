# 隐藏图标代理窗口路由

## MODIFIED Requirements

### Requirement: AX owner 与原生窗口 owner 不一致时仍可安全定位

系统 SHALL 在 AX 菜单项没有窗口编号、同 AX PID 无可用 status-window，但 WindowServer 菜单栏清单存在唯一几何匹配的跨 PID status-window 时，将该真实窗口作为原生点击目标。

#### Scenario: 唯一跨 PID 代理窗口

- WHEN AX 项目 PID 为 75732、frame 为 `(-3016,3,38,24)`、没有 AX window ID
- AND WindowServer 中同 PID 没有匹配 status-window
- AND 存在唯一 `pid=1284 window=7619 layer=25 frame=(-3015,0,36,30)` 的菜单栏窗口
- THEN 目标窗口 SHALL 为 7619
- AND 原生事件目标 PID SHALL 为 1284
- AND 点击位置 SHALL 对应 AX 项目中心在该窗口中的局部坐标

#### Scenario: 同 PID 候选本身有歧义

- WHEN 同 AX PID 存在多个包含 AX 矩形的 status-window
- THEN 不得启用跨 PID fallback
- AND 不得选择任意 foreign-owner 窗口

#### Scenario: 跨 PID 候选有歧义

- WHEN 同 PID 无候选，但存在两个或更多跨 PID status-window 同时匹配 AX 几何
- THEN 不投递点击
- AND 诊断记录 proxy 候选数量

#### Scenario: authoritative AX window ID 失效

- WHEN AX 已提供窗口编号但该窗口无法验证
- THEN 不得通过几何改选同 PID或跨 PID 的其他窗口

#### Scenario: 投递前 owner 变化

- WHEN 代理目标已解析，但投递前 WindowServer 返回的 window owner PID 与已保存 PID 不一致
- THEN 取消投递

# 隐藏图标原生窗口发现

## ADDED Requirements

### Requirement: 查询公共清单遗漏的菜单栏窗口

系统 SHALL 在公共窗口查询无法匹配图标时，查询 WindowServer 专用菜单栏清单。

#### Scenario: 无 AXWindow 且公共清单不包含图标窗口

- WHEN AX 图标具备有效屏幕外矩形，但没有窗口编号，公共列表仅有无法匹配的普通窗口
- THEN 查询专用菜单栏清单
- AND 仅当存在唯一同 PID 且包含 AX 图标区域的菜单栏窗口时定位成功
- AND 无需展开普通隐藏区或持续隐藏区

#### Scenario: 专用清单中的普通窗口

- WHEN 无 AX 窗口编号，专用清单中的窗口层级不是 status-window
- THEN 不将它当作状态项进行几何匹配
- AND 不得仅凭清单成员身份接受普通 layer 0 窗口

#### Scenario: 投递前复核

- WHEN 目标通过 WindowServer 查询定位
- THEN 投递前使用 WindowServer 读取实时窗口所有者和矩形
- AND 进程不匹配、窗口消失或尺寸变化时不投递

#### Scenario: 查询无法完成

- WHEN 私有接口不可用、清单查询失败、目标不存在或有歧义
- THEN 保留面板错误和可复制诊断
- AND 不向其他窗口或全局屏幕投递兜底点击

# 隐藏图标面板

## MODIFIED Requirements

### Requirement: 隐藏状态下的原生左右键

面板 SHALL 将左键映射为目标图标的 leftMouseDown/leftMouseUp，将右键及 Control-click 映射为 rightMouseDown/rightMouseUp。不得用左键动作替代右键。

#### Scenario: 隐藏图标单次点击

- WHEN 用户在面板点击普通隐藏或持续隐藏图标
- THEN 系统定向投递到同一原生图标窗口
- AND 用户无需显示全部图标或到菜单栏再次点击
- AND 隐藏状态、spacer 宽度、图标排列和鼠标位置不变

### Requirement: 有效目标与事件生命周期

系统 SHALL 使用当前窗口身份和位置，先结束面板点击再投递原生事件；不得在投递后盲目重复 AX 动作。

#### Scenario: 目标失效

- WHEN 应用退出、原窗口消失或匹配不唯一
- THEN 不投递任何全局点击
- AND 面板提示刷新后重试

#### Scenario: 权限或设置变化

- WHEN 辅助功能权限缺失，或等待中发生设置、屏幕、状态、刷新变化
- THEN 不投递过期操作
- AND 基础隐藏功能仍无需辅助功能权限

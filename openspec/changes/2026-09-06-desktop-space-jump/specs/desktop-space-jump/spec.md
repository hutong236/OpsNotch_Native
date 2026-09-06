# Desktop Space Jump

## Requirements

### Requirement: 桌面命令解析
系统 MUST 将 `dN` 解析为全局第 N 个可切换 Desktop/Space，并 MUST 支持 `d`、`desktop`、`桌面` 打开桌面列表。

#### Scenario: 直接跳转
- GIVEN 用户已呼出 Ops Notch
- WHEN 用户输入 `d2`
- THEN 系统直接发起到全局桌面 2 的跳转

### Requirement: 实时 Space 拓扑
系统 MUST 在执行或列出桌面时读取当前显示器和 Space 拓扑，不得依赖启动时固定缓存。

#### Scenario: 显示器发生变化
- GIVEN 用户插入或拔出显示器
- WHEN 用户再次输入桌面命令
- THEN 桌面编号基于最新拓扑重新生成

### Requirement: 原生 Space 切换
系统 MUST 优先通过 Dock/WindowServer 的原生 Space 行为完成切换，并 MUST 提供不依赖用户快捷键配置的 fallback。

#### Scenario: Dock gesture 不可用
- GIVEN 默认 Dock gesture 未能使目标 Space 成为 Current Space
- WHEN fallback 被触发
- THEN 系统使用 HID System Event Source 发送 Control+方向键并再次确认目标 Space

### Requirement: 工作上下文跟随
切换成功后系统 MUST 将鼠标移动到目标显示器，并 SHOULD 恢复该 Space 上次鼠标位置和可见窗口焦点。

#### Scenario: 再次进入使用过的桌面
- GIVEN 桌面 2 已记录上次鼠标位置
- WHEN 用户从其他桌面执行 `d2`
- THEN 鼠标恢复到该位置，且目标显示器上的工作窗口获得焦点

### Requirement: 安全降级
系统 MUST 在 Accessibility 未授权或 SkyLight 读取不可用时给出可理解提示，且 MUST NOT 要求关闭 SIP 或注入系统进程。

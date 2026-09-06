# Desktop Accessibility Retry Specification

## Requirement: 首次授权后续执行
当用户执行 Desktop 切换且 Ops Notch 尚未获得 Accessibility 权限时，系统应发起授权请求，并在权限生效后继续当前切换命令，而不是要求用户重新输入。

### Scenario: 首次授权成功
- GIVEN Ops Notch 尚未获得 Accessibility 权限
- WHEN 用户执行 `d 2` 并确认
- THEN macOS 显示辅助功能授权提示
- AND 用户允许后原命令自动继续
- AND Desktop 2 成为当前 Space

### Scenario: 用户未授权
- GIVEN Ops Notch 尚未获得 Accessibility 权限
- WHEN 用户未在等待窗口内完成授权
- THEN 当前命令结束
- AND 返回明确的 Accessibility 权限提示

## Requirement: HID fallback 使用原生组合键
当 Dock gesture 未能完成切换时，HID fallback MUST 使用 `Control + Left/Right`，不得附加 Fn modifier，并继续验证目标 Space 是否成为 current。

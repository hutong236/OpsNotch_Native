# Proposal: Desktop 辅助功能授权后自动续执行

## 背景
Desktop 快速切换依赖 macOS Accessibility 权限。当前首次执行时会弹出系统授权提示，但代码立即判定未授权并结束命令，导致用户看到提示后桌面没有切换。

## 目标
- 首次执行 Desktop 命令时请求 Accessibility 权限。
- 用户完成授权后继续原来的桌面切换，不要求重新输入命令。
- 未授权超时后明确返回权限错误。
- HID fallback 使用 Mission Control 原生 `Control + Left/Right` 组合。

## 非目标
- 不绕过 macOS TCC 权限。
- 不关闭 SIP。
- 不改变 Desktop 编号、SkyLight 拓扑读取或统一搜索交互。

## 关联
- GitHub Issue #33

# Design

## 权限流程

`DesktopSpaceController.switchToDesktop()` 在执行 Space 切换前异步检查 Accessibility：

1. 已授权：直接继续。
2. 未授权：调用 `AXIsProcessTrustedWithOptions(prompt: true)` 请求系统授权。
3. 以 250ms 间隔短时检查 `AXIsProcessTrusted()`。
4. 授权生效后继续同一次切换。
5. 最长约 45 秒仍未授权则返回 `.accessibilityRequired`。

该等待使用 `Task.sleep`，不会持续阻塞主线程，并支持 Task 取消。

## HID fallback

Mission Control 的原生 Space 左右切换使用：

```text
Control + Left
Control + Right
```

因此 HID fallback 仅设置 `.maskControl`，不再设置 `.maskSecondaryFn`。多步切换仍在每步之间保留短暂间隔，并通过 SkyLight 当前 Space 状态确认是否成功。

## 签名说明

当前 GitHub Release 为 ad-hoc 签名。macOS TCC 可能在应用版本或签名身份变化后再次要求用户确认 Accessibility。该问题与本次“授权后命令不继续”的运行时 bug 分开处理；长期建议使用固定 Developer ID 签名发布。

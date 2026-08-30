# Ops Notch Native V2.0 测试报告

## 当前环境实际执行

### Swift Core Tests

```text
8 tests passed
0 failures
```

覆盖：

- Legacy `ip/command` → Text
- V0.1 array migration
- Pinned ordering
- Search
- Recent TTL
- Reference delete safety
- Copy-in lifecycle
- Safe Action validation

### Static Architecture Checks

```text
PASS no Tauri
PASS no React
PASS no Vite
PASS native dragging destination
PASS clipboard changeCount
PASS multi display
PASS native status item
PASS quick look
PASS login item
PASS accessory app
PASS safe action guard
PASS no global shortcut plugin
```

### Swift Syntax Parse

所有 `Sources/OpsNotchApp/*.swift` 已通过 `swiftc -frontend -parse`。

## 当前环境无法执行

当前运行环境为 Linux，没有 macOS SDK / AppKit，因此不能把以下项目标记为通过：

- macOS AppKit 类型检查
- `swift build` 的 macOS target
- Xcode 编译
- NSPanel / Sensor 实机显示
- `NSDraggingDestination` Text Drag
- 三指拖移
- NSScreen 多显示器实机
- QLPreviewPanel
- NSStatusItem
- SMAppService
- `.app` codesign / launch

这些项目必须在真实 Mac 或 macOS GitHub Actions 验证。

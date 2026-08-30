# Ops Notch Native V2.0 架构

## 1. 总体架构

```text
OpsNotch.app
│
├── AppDelegate
│
├── SensorManager                  AppKit
│   ├── SensorPanel Display-1
│   ├── SensorPanel Display-2
│   └── SensorPanel Display-N
│       └── SensorView
│           ├── NSTrackingArea
│           └── NSDraggingDestination
│
├── ShelfWindowController          AppKit + SwiftUI Hosting
│   └── ShelfRootView
│       ├── Pinned
│       ├── Recent
│       ├── Search
│       ├── Item Editor
│       └── Native Drag Source
│
├── ClipboardManager               NSPasteboard
├── ItemActionService              NSWorkspace
├── QuickLookService               QLPreviewPanel
├── StatusBarController            NSStatusItem
├── SettingsWindowController       SwiftUI
├── LoginItemService               SMAppService
│
└── OpsNotchCore
    ├── ShelfItem / ShelfSettings
    ├── ShelfLogic
    ├── ShelfStoreService
    └── SafeActionValidator
```

## 2. 为什么 Sensor 使用 AppKit

Sensor 是整个产品最 macOS-specific 的部分，因此不用 SwiftUI 手势模拟，而是直接使用：

- `NSPanel`
- `NSTrackingArea`
- `registerForDraggedTypes`
- `NSDraggingDestination`
- `NSPasteboard`

这样 Text Drag 和 File Drag 走同一条 macOS 原生 Drag Session。

## 3. 多显示器

`SensorManager` 使用：

```swift
NSScreen.screens
```

为每块目标屏幕建立一个透明 Sensor。

并监听：

```swift
NSApplication.didChangeScreenParametersNotification
```

处理显示器：

- 插入
- 拔出
- 排列变化
- 分辨率变化
- 缩放变化

不再使用 V1.x 的 1.5 秒轮询。

## 4. 文字拖入

```text
Source App
   │
   │ macOS Drag Pasteboard
   ▼
SensorView
   │
   ├── .fileURL → File/Folder
   ├── .URL     → http/https URL
   └── .string  → Text
```

Shelf 显示在 Sensor 下方，因此不会覆盖当前原生 Drag Destination。

## 5. Clipboard Catch

启动时：

```text
NSPasteboard.general.changeCount
            ↓
        作为 baseline
```

用户复制后触碰 Sensor：

```text
changeCount changed
      ↓
read .string
      ↓
add Text to Recent
```

如果 Text 是 Ops Notch 自己点击复制产生，ClipboardManager 会立即更新 baseline，避免下一次碰刘海又把同一个内容重新加入。

## 6. 数据安全

Safe Action 只允许：

- `/absolute/local/path`
- `http://...`
- `https://...`

没有 Shell、SSH、kubectl、Terminal command 自动执行能力。

## 7. UI 层

AppKit 管系统交互和窗口生命周期；SwiftUI 仅管理内容层：

```text
AppKit = 壳 / 系统能力
SwiftUI = 内容 / 设置
```

这样避免把刘海、窗口、拖放做成 Web/SwiftUI 手势状态机。

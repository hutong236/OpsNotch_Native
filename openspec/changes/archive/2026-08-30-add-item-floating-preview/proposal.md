## Why

Shelf 目前对文字条目只显示单行截断的小字标题,图片条目与普通文件一样只显示一个 24x24 的系统图标;想看清内容只能点 QuickLook 或用系统"预览"打开,后者会在桌面上弹出整个 Preview 窗口,遮挡用户正在操作的工作区,实际使用体验很差。用户需要一个"参照模式":把文字/图片放大后常驻悬浮在所有窗口之上,一边干其他活一边对照内容。

## What Changes

- 文字条目与图片文件条目(按文件扩展名识别)的悬停操作按钮区新增"放大预览"按钮(`arrow.up.left.and.arrow.down.right` 图标),右键菜单同步新增"放大预览"入口。
- 点击放大按钮后,新开一个**置顶悬浮预览窗**(AppKit NSPanel,非激活、不抢焦点、`hidesOnDeactivate = false`),内容常驻显示在最上层,直到用户手动关闭;再次对其他条目点放大时替换窗口内容。
- 文字预览优化:大字号、自动换行、全文可滚动、文本可选中复制,提供字号调节(+ / −)。
- 图片预览优化:图片不再走"打开整个桌面/Preview"的路径,而是直接在悬浮窗内渲染 `NSImage`,按比例缩放适配窗口,支持滚轮/捏合缩放与拖动平移。
- 预览窗关闭后 Shelf 的自动隐藏逻辑不受影响;预览窗打开期间 Shelf 面板照常工作。
- 新增 UI 文案需同时加入 zh/en 两套 `L10n` 字典。

## Capabilities

### New Capabilities

- `item-floating-preview`: 文字/图片条目的置顶悬浮放大预览 —— 放大入口、悬浮窗层级与常驻行为、文字与图片的显示与缩放交互、与 Shelf 自动隐藏逻辑的共存。

### Modified Capabilities

(无 —— 既有 shelf-items 置顶行为的规格不变;条目行新增按钮属于新能力的入口,在 `item-floating-preview` 中定义。)

## Impact

- `Sources/OpsNotchApp/ShelfView.swift`:行内操作按钮区、右键菜单新增"放大预览"入口;需判断条目是否为文字/图片。
- 新增 `Sources/OpsNotchApp/FloatingPreviewController.swift`(AppKit 层):管理置顶 NSPanel 与预览内容(文字 SwiftUI 视图 / NSImageView)。
- `Sources/OpsNotchApp/Localization.swift`:新增 zh/en 文案。
- `Sources/OpsNotchApp/ShelfWindowController.swift`:确认自动隐藏判定与预览窗共存(预览窗独立于 Shelf 面板,不互相干扰)。
- 图片判定按扩展名(jpg/jpeg/png/gif/webp/heic/tiff/bmp 等)实现为 Core 纯函数(保持 UI-free、可单元测试),Core 模型本身不变。
- 不涉及 `OpsNotchCore`(无持久化变更、无安全动作变更,预览只读内容,不执行任何 open/shell)。

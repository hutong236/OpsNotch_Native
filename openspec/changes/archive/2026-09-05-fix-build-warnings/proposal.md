## Why

`swift build` 在 App 目标产生 3 个编译器警告,其中 `FloatingPreviewController.swift` 的 `event.momentumPhase == .none` 比较在当前 SDK 下恒为 `false`,导致 `guard` 总是提前 return——图片悬浮预览的滚轮缩放完全失效,违反既有 spec(item-floating-preview「图片预览显示优化」要求滚轮缩放)。另外两个是 Swift 6 严格并发的前置警告(`QLPreviewPanelDataSource` conformance 隔离、`@Sendable` 闭包捕获非 Sendable 的 `NSMetadataQuery`),未来切换 Swift 6 语言模式会升级为 error,应趁早清零。

## What Changes

- 修复 `FloatingPreviewController.swift` `ImagePreviewView.scrollWheel`:改用 OptionSet 语义 `event.momentumPhase.isEmpty` 判断惯性阶段,恢复滚轮缩放,同时保留"惯性阶段不参与缩放"的原有意图。
- 修复 `QuickLookService.swift`:`QLPreviewPanelDataSource` conformance 标注 `@preconcurrency`,消除 conformance-isolation 警告(QLPreviewPanel 及其 data source 本就限定主线程使用)。
- 修复 `SpotlightRevealService.swift`:通知回调不再捕获 `NSMetadataQuery`,改为从 `notification.object` 取回查询对象,消除非 Sendable 捕获警告。
- 不新增/删除任何对外能力;除"滚轮缩放恢复可用 + 惯性不续缩"外,行为与现状完全一致。

## Capabilities

### New Capabilities

(无)

### Modified Capabilities

- `item-floating-preview`:「图片预览显示优化」要求下新增一个场景——滚轮松手后的惯性(momentum)滚动阶段 MUST NOT 继续缩放。该行为是代码注释中既有意图,但 spec 此前未显式约束;修复 momentumPhase 比较后该行为首次真正可观察,故以 delta 显式化。

## Impact

- 代码:`Sources/OpsNotchApp/FloatingPreviewController.swift`(scrollWheel 一处)、`Sources/OpsNotchApp/QuickLookService.swift`(类声明一行)、`Sources/OpsNotchApp/SpotlightRevealService.swift`(通知闭包一处)。
- 不触碰 `OpsNotchCore`、持久化格式、shell.json 兼容性或任何协议/API。
- `scripts/static_checks.py` 要求的精确调用点(`QLPreviewPanel`、`SafeActionValidator.validate` 等)均不受影响。
- 验收:`swift build` 零警告;`swift test` 与 `scripts/static_checks.py` 保持通过;滚轮缩放需按 VERIFY_ON_MAC 在打包 .app 中人工实测。

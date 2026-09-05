## Context

当前 SDK(macOS 13+ 的 AppKit)里 `NSEvent.momentumPhase` 已是非可选的 `NSEvent.Phase`(OptionSet),老代码 `event.momentumPhase == .none` 实际是在和 `Optional<Phase>.none` 比较,恒为 `false`——`ImagePreviewView.scrollWheel` 的 `guard` 因此总是提前返回,滚轮缩放完全失效(违反主 spec 既有场景「缩放查看细节」)。另外两处警告来自 Swift 6 严格并发检查在 Swift 5 模式下的前置提示:`@MainActor` 类对非隔离协议 `QLPreviewPanelDataSource` 的 conformance,以及 `NotificationCenter.addObserver(forName:object:queue:)` 的 `@Sendable` 闭包捕获非 Sendable 的 `NSMetadataQuery`。已用全量构建确认全部警告就是这三处,无 error。

约束:`scripts/static_checks.py` 扫描全部 Swift 源并要求若干精确调用点(含 `QLPreviewPanel`)原样存在;Core 层不许 import AppKit;三项修复全部落在 `OpsNotchApp`。

## Goals / Non-Goals

**Goals:**

- `swift build` 对三个 App 目标文件零警告。
- 恢复图片悬浮预览的滚轮缩放,并保留"惯性阶段不缩放"的既有意图(以 spec 场景显式化)。
- 两处并发标注消除后,未来切 Swift 6 语言模式不在这三处升级为 error。

**Non-Goals:**

- 不做整体 Swift 6 语言模式迁移。
- 不重构 QuickLookService / SpotlightRevealService 的结构,不引入 selector 式通知等更大改动。
- 不触碰 QuickLook 面板的行为逻辑(数据源数量、条目返回值均不变)。

## Decisions

### 1. momentumPhase 判空用 OptionSet 语义 `.isEmpty`

`guard event.momentumPhase.isEmpty else { return }`。`NSEvent.Phase` 是 OptionSet,`isEmpty` 即"无任何相位标志",语义与原注释"惯性阶段不参与缩放"完全一致,且对 Optional/非可选 SDK 都成立。

- 备选:`event.momentumPhase.rawValue == 0` 或与 `NSEvent.Phase([])` 比较——语义等价但不如 `.isEmpty` 惯用,弃。
- 行为影响:这是本变更唯一的行为修复——普通滚轮缩放从"完全失效"恢复为"可用",惯性不缩放的意图得以真正生效。

### 2. QuickLookService 用 `@preconcurrency` conformance

类声明改为 `final class QuickLookService: NSObject, @preconcurrency QLPreviewPanelDataSource`。`QLPreviewPanel` 及其 data source 协议按 Apple 文档限定主线程使用,service 整体已是 `@MainActor`,witness 方法只会在主线程被面板回调,不存在真实数据竞争;`@preconcurrency` 是编译器三条修复建议里唯一不改方法签名、不放宽类内隔离的方案。

- 备选 A:把两个 witness 方法标 `nonisolated`——方法内要读 `@MainActor` 的 `previewURL`,得再套 `unsafe`/`assumeIsolated`,复杂且无收益,弃。
- 备选 B:去掉类级 `@MainActor`——削弱其余代码的隔离安全,弃。

### 3. SpotlightRevealService 从通知对象取回 query

回调改为不捕获 `query`,签名带出通知后 `guard let self, let note else …; guard let query = note.object as? NSMetadataQuery` 取回。`addObserver` 已传 `object: query`,通知只可能来自该查询,cast 必然命中;`NSMetadataQuery` 非 Sendable,弱引用捕获正是警告来源,移除捕获即根除。

- 备选 A:改 selector 式 `addObserver(self, selector:…)`——改动面大、丢掉 `queue: .main` 的便利,弃。
- 备选 B:给 query 包一层 `@unchecked Sendable`——为消一个警告引入包装类型,过度设计,弃。
- `queue: .main` + `MainActor.assumeIsolated` 结构保持不变。

### 4. 静态检查调用点保持

三处改动均为局部表达式/标注修改,不触碰 `QLPreviewPanel`、`SafeActionValidator.validate` 等 `static_checks.py` 要求的精确字符串;不引入 `tauri`/`react`/`vite`/`global-shortcut` 字样。

## Risks / Trade-offs

- [`@preconcurrency` 只是豁免检查,不改变运行时行为] → QLPreviewPanel 本就主线程限定,且类是 `@MainActor`,实际无竞争面;Swift 6 迁移时再统一复核。
- [滚轮缩放恢复是用户可感知的行为变化(从失效到可用)] → 按 VERIFY_ON_MAC 在打包 .app 中人工实测悬浮预览缩放与惯性表现。
- [`momentumPhase.isEmpty` 依赖 Phase 的 OptionSet 形态] → 最小平台 macOS 13,该形态由 AppKit SDK 保证,无兼容风险。

## Migration Plan

无持久化、格式或配置变更,三处小改动随构建直接生效;回滚即 revert 对应三个文件的改动。

## Open Questions

(无)

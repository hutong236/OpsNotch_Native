## Context

键盘取回流(`add-hotkey-summon`,工作区已实现)已提供:面板 key 窗化(`ShelfPanel.canBecomeKey` + `makeKey()`)、`ShelfWindowController.keyMonitor` 本地 keyDown 监听(↑↓/Enter/Esc)、`AppModel.highlightedID` 高亮模型、搜索框自动聚焦(`focusRequestToken`)。本变更在其上叠加类型筛选,不重复造键盘机制。

约束(来自 AGENTS.md 与既有架构):
- Core 保持 UI/AppKit-free,筛选逻辑放 `ShelfLogic` 可单测。
- AppKit 拥有系统交互(AppKit 层 keyMonitor 接管按键),SwiftUI 只做内容渲染。
- `static_checks.py` 锁定的 API 调用点不动;新增文案进 `Localization.swift` zh/en 两套字典。
- 项目门槛 macOS 13:不用 `onKeyPress`(macOS 14+),沿用 keyMonitor。

## Goals / Non-Goals

- Goals:类型筛选 chips、与键盘流打通(⌘1~⌘5、高亮回落、Space 预览)、新增条目不被筛选藏住、Core 层可测。
- Non-Goals:不持久化筛选状态、不改存储格式、不做网格视图/时间分段(后续候选)、不给 chips 做 Tab 焦点环遍历(快捷键已覆盖)。

## Decisions

### D1. `ShelfKindFilter` 放 Core,`grouped` 加默认参数

`ShelfLogic.swift` 新增:

```swift
public enum ShelfKindFilter: Equatable, Sendable, CaseIterable {
    case all, file, text, url, application
}
```

`matches(_:query:kind:)` 与 `grouped(_:query:kindFilter:)` 增加带默认值(`.all`)的参数,旧签名调用点与既有测试零改动。归类映射:

- `.file` ⇢ `kind == .file || .folder || (kind == .action && actionKind == .openPath)`
- `.url` ⇢ `kind == .url || (kind == .action && actionKind == .openURL)`
- `.text` ⇢ `kind == .text`;`.application` ⇢ `kind == .application`;`.all` ⇢ 恒真

筛选发生在 `ordered` 排序之后、pinned/recent 拆分之前,保证分区结构与 SectionHeader 的 `index == groups.pinned.count` 逻辑不被破坏。

### D2. 筛选状态在 AppModel,`didSet` 回落高亮

`AppModel` 增加 `@Published var kindFilter: ShelfKindFilter = .all`,`didSet` 中执行与 `query.didSet` 相同的高亮回落(`highlightedID = visibleItems.first?.id`)。`grouped`/`visibleItems` 计算属性传入 `kindFilter`。

新增条目回退"全部":在私有 `apply(_:)` 里对比前后条目 id 集合,若有新 id 且其中任一不满足当前筛选,则 `kindFilter = .all`。集中在单一入口,拖入/剪贴板/手动添加各链路自动覆盖。

### D3. keyMonitor 扩展 ⌘数字与 Space(AppKit 层)

`ShelfWindowController.keyMonitor` 的 switch 增加分支(守住既有前置条件:panel key 窗、expanded、`editorDraft == nil`):

- ⌘ + keycode 18/19/20/21/23(数字 1–5)→ `model.setKindFilter(to:)`,吞掉事件。判定修饰键:`event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command`,避免误吃 ⇧数字等。
- Space(keycode 49,无修饰键)→ 高亮条目 Quick Look,吞掉事件;前置条件增加"搜索框未聚焦":`!(panel.firstResponder is NSTextView)`。field editor(搜索框)聚焦时事件原样放行,保证正常打字。
- AppModel 增加 `quickLookHighlighted()`:取高亮条目,`ItemPreviewKind.isPreviewable(item)` 通过后调 `QuickLookService.shared.preview(item)`;不收面板、不写剪贴板。

### D4. chips 行 UI(ShelfView)

搜索栏与 selectionBar 之间插入一行 HStack:五个 `.borderless` Button,选中项用 accent 胶囊底色 + 主色文字,未选中 `.secondary`;文案键 `filterAll/filterFile/filterText/filterURL/filterApp`(zh:全部/文件/文本/URL/应用)。键盘高亮行样式用 `Color.primary.opacity(0.08)`,与 hover(0.055)、多选选中(accent 0.12)可区分,仅改背景色不动布局。

无结果空态:内容区在 `groups.pinned.isEmpty && groups.recent.isEmpty` 且(`query` 非空 **或** `kindFilter != .all`)时显示"没有匹配的条目"(`noMatch` 键),否则维持空柜视图。

(实现期修订:键盘高亮行样式沿用 hotkey-summon 已落地的"白描边 + 0.10 灰底"实现,不再另设 0.08 底色——该样式已写入 VERIFY_ON_MAC 第 16 节验收口径,保持一致。)

### D5. 与 add-hotkey-summon 的合并顺序

~~⌘1~⌘5 与 Space 的接管点都在 hotkey-summon 引入的 keyMonitor 上,需先合并该变更~~(已解决:add-hotkey-summon 实现已作为 `d7faf1f feat(hotkey)` 落入 main,本变更直接在其结果上扩展。)

## Risks / Trade-offs

- keyMonitor 扩展出两个新分支,需保证编辑弹窗(`editorDraft != nil`)下全部让行——沿用既有 guard,任务里补手测项。
- Space 接管依赖 firstResponder 判定,若搜索框 field editor 判定失效会导致打空格触发预览;以"搜索框聚焦时按 Space 出空格"为验收项兜底。
- 新增条目回退"全部"依赖 apply 前后 id diff,若未来存储层出现非追加式新增(如批量导入)需复核该逻辑。

## Open Questions

无(筛选不持久化、chips 顺序、⌘1~⌘5 映射均已在 spec 定案)。

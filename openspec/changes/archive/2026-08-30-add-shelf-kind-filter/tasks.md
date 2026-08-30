## 1. Core:类型筛选模型与过滤函数

- [x] 1.1 `ShelfLogic.swift` 新增 `ShelfKindFilter`(Equatable/Sendable/CaseIterable,case `all/file/text/url/application`);`matches` 与 `grouped` 增加带默认值(`.all`)的筛选参数,归类规则:file+folder+openPath action → 文件,url+openURL action → URL,text → 文本,application → 应用;验证 `swift test` 通过且既有调用点/迁移测试零改动
- [x] 1.2 新增 XCTest:五种筛选位各自只放行对应类型(action 两种 actionKind 分别归入文件/URL)、与搜索词叠加取交集、`query`/`kindFilter` 同传时 pinned/recent 分区拆分正确(置顶条目仍居 Pinned 区)、默认参数等价于旧行为;验证 `swift test` 全绿

## 2. App:AppModel 筛选状态

- [x] 2.1 `AppModel` 新增 `@Published var kindFilter: ShelfKindFilter = .all`,`didSet` 将 `highlightedID` 回落到过滤结果首行(与 `query.didSet` 同规则);`grouped`/`visibleItems` 传入 `kindFilter`;新增 `setKindFilter(to:)`;验证 `swift build` 通过
- [x] 2.2 私有 `apply(_:)` 中对比前后条目 id:出现新条目且任一不满足当前筛选时重置 `kindFilter = .all`;新增 `quickLookHighlighted()`(高亮条目过 `ItemPreviewKind.isPreviewable` 后调 `QuickLookService.preview`,不收面板不写剪贴板);验证真机:文本筛选下拖入文件,筛选自动回"全部"且新条目可见

## 3. App:ShelfView chips 与样式

- [x] 3.1 搜索栏下新增筛选 chips 行(全部/文件/文本/URL/应用五个 borderless Button):选中态 accent 胶囊底 + 主色文字,点击即 `setKindFilter`;条目行键盘高亮背景改用 `Color.primary.opacity(0.08)`,与 hover(0.055)/多选选中(accent 0.12)可区分;验证真机:chips 点击切换、分区头与计数随筛选正确增减
- [x] 3.2 空态区分:过滤后为空且(`query` 非空或 `kindFilter != .all`)显示"没有匹配的条目",否则维持空柜视图;验证真机:应用筛选无条目时出现无结果提示、清柜时仍是空柜提示

## 4. App:keyMonitor 键盘分支

- [x] 4.1 `ShelfWindowController.keyMonitor` 增加 ⌘1~⌘5(keycode 18/19/20/21/23,修饰键恰好为 .command)→ `setKindFilter`,与 Space(keycode 49、无修饰、`!(panel.firstResponder is NSTextView)`)→ `quickLookHighlighted()`;沿用既有前置条件(panel key 窗、expanded、`editorDraft == nil`);验证真机:⌘1~⌘5 切换 chips、筛选变化后高亮回落首行、Space 预览高亮图片/文件且面板不收起
- [ ] 4.2 键盘流兼容性手测:搜索框聚焦时按 Space 输入空格不触发预览;编辑弹窗打开时 ⌘数字/Space/↑↓/Enter 全部让行;⌘数字不误触 ⇧/⌃/⌥ 组合;筛选后 ↑↓/Enter 复制/Esc 收起行为与 spec 一致

## 5. 文案与设置一致性

- [x] 5.1 `Localization.swift` zh/en 增加 `filterAll/filterFile/filterText/filterURL/filterApp/noMatch` 六键(zh:全部/文件/文本/URL/应用/没有匹配的条目);验证设置页切换 zh/en,chips 与空态文案双语言正确

## 6. 文档与门禁

- [x] 6.1 VERIFY_ON_MAC.md 验收清单补充:chips 筛选、⌘1~⌘5、高亮回落、Space 预览、文本筛选拖入文件自动回"全部"、重启恢复"全部";验证 AGENTS.md 架构规则未被触碰(Core 无 AppKit import、无轮询回归)
- [x] 6.2 全量门禁:`swift test`、`swift build`、`python3 scripts/static_checks.py` 依次执行退出码为 0;确认未改动 static_checks 锁定的 API 调用点与存储格式

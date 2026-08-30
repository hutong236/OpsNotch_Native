## Context

置顶/取消置顶的数据链路(`ShelfStoreService.setPinned` → JSON 落盘 → `AppModel.togglePin` → `apply` → `ShelfLogic.grouped` 分组)经代码审查与 8 个 Core 单测确认无缺陷,本变更不触碰该链路。问题位于 AppKit 交互层:

- `ShelfWindowController.scheduleHide` 的隐藏判定只有两个条件——`!model.shelfHovered` 与 `editorDraft == nil`——满足即无条件 `panel.orderOut(nil)`。
- 隐藏有两个触发源:sensor `mouseExited`(0.5s)和 SwiftUI `.onHover(false)` → `shelfHoverChanged(false)`(0.35s)。
- 右键上下文菜单是独立窗口,打开后鼠标移入菜单会令面板的 NSTrackingArea 触发 `mouseExited` → `.onHover(false)` → `scheduleHide(0.35)`;主队列 work item 在 common modes 上执行,菜单跟踪期间照常到期,于是面板在菜单正被使用时被 `orderOut`。右键菜单里的"取消置顶"(位于菜单较下方的项)由此经常点不到——与用户报告"取消置顶没有实现"吻合。
- 另一个不利几何因素:面板高 560pt,菜单自光标向下展开约 150pt;列表靠下的行上打开菜单时,"取消置顶"项可能落在面板 frame 之外,仅按"鼠标是否在面板内"判断不足以覆盖。

运行时复现受本机权限限制(屏幕录制/辅助功能未授权),验收必须回到真机按 `VERIFY_ON_MAC.md` §9 执行。

## Goals / Non-Goals

**Goals:**

- 右键菜单(含"取消置顶")打开期间,shelf 面板与菜单不被自动隐藏打断;菜单关闭且鼠标离开后再正常隐藏。
- 两个取消置顶入口(悬停 pin.slash 按钮、右键菜单)在真机上端到端可用,结果落盘并在重启后保持。
- 不改变正常场景的隐藏体验:鼠标真正离开 shelf 区域后仍按原延时消失。

**Non-Goals:**

- 不新增取消置顶的第三入口、不改 ShelfView 布局(除非验证发现悬停按钮路径另有缺陷,届时最小修复)。
- 不修改 Core 数据模型、`shelf.json` 格式与 legacy 迁移。
- 不处理 sensor 拖放、剪贴板去重等其他交互。

## Decisions

### D1: 隐藏 work item 增加生效前置条件——鼠标位置 + 菜单跟踪双信号,不满足则重新调度

`scheduleHide` 的 work item 到期时,先判定再隐藏:

1. 原有守卫保留:`!model.shelfHovered` 且 `editorDraft == nil`;
2. 新增两个"暂缓隐藏"信号,任一成立则 `scheduleHide(delay: 0.35)` 重新调度、不 `orderOut`:
   - **鼠标仍在面板 frame 内**:`panel.frame.contains(NSEvent.mouseLocation)`(两者同为 Cocoa 全局坐标,可直接比较)。覆盖"菜单窗口遮挡面板导致 hover 失同步"的主场景;
   - **有菜单正在跟踪**:`NSApp.keyWindow?.level == .popUpMenu`。上下文菜单/状态栏菜单跟踪时其窗口处于 `.popUpMenu` 层级,覆盖"菜单下探出面板 frame、光标落在面板外菜单项上"的几何盲区;
3. 两信号均不成立才 `panel.orderOut(nil)`。

收敛性:菜单关闭且鼠标离开面板后,下一次到期判定必然走到 `orderOut`;若菜单关闭时鼠标仍在面板上方,SwiftUI `.onHover(true)` 恢复 `shelfHovered`,守卫直接返回,面板随悬停保持——行为与用户预期一致。重新调度是事件驱动的有限续期(仅在菜单会话期间每 0.35s 续一次),与 V1.x 被禁止的 1.5s 屏幕轮询无关,不违反架构规则。

- *备选:全局加大隐藏延时(0.35→2s)* —— 治标,读菜单耗时不可控,仍可复现,且拖慢正常隐藏,不采纳。
- *备选:感知 `.contextMenu` 生命周期,打开期间不调度隐藏* —— SwiftUI 不提供菜单打开/关闭回调,需私有 API 或自绘 NSMenu,复杂度高,不采纳。
- *备选:移除 `shelfHoverChanged(false)` 触发源* —— 鼠标从面板下方离开(不经 sensor)时面板永不隐藏,行为回退,不采纳。

### D2: ShelfView 悬停按钮路径——D1 修复后真机仍复现,实测定位到第二根因(已触发预留路径)

D1 修复后真机验收仍复现:条目置顶成功(`shelf.json` 中 `pinned: true`)并已移入 Pinned 分区,但该行悬停按钮仍渲染未置顶图标(`pin` 而非 `pin.slash`),右键菜单项仍显示"置顶";点击该按钮执行 `togglePin(过期 item)` → `setPinned(true)`,条目永远无法取消置顶——与 D1 的隐藏竞态共同构成"取消置顶没有实现"的完整成因。

截图证据同时显示:条目移入 Pinned 后,该行的悬停高亮与操作按钮保持展开——`@State hovered` 跨分区移动被保留,证明 `LazyVStack` 把同一条目 id 在两个 `ForEach` 之间移动时复用了旧 cell(旧 `item` 值 + 旧状态),SwiftUI 未以新值更新行内容。修复见 D5。

### D3: Core 层补 `setPinned` 取消置顶回归测试

新增用例:置顶 → `setPinned(false)` → 重新 `load()` 校验 `pinned == false` 且 `grouped` 归入 Recent;以及取消置顶条目重新进入 TTL 过期资格(`expiredIDs` 不再豁免)。App 层(`AppModel`/交互)不进单测,由真机验收覆盖——与现有"Core 可测、交互手测"的分层一致。

### D4: 不触碰 static_checks.py 受检调用点

改动集中在 `ShelfWindowController`;`NSEvent.mouseLocation`、`NSApp.keyWindow` 均非检查器约束的调用点,`registerForDraggedTypes`、`changeCount` 等受检 API 不受影响。

### D5: Shelf 列表改为单个 ForEach 渲染,分区头内联(修复 D2 实测的过期行)

原 `content` 用两个 `ForEach` 分别渲染 `groups.pinned` 与 `groups.recent`;同一条目 id 在两个 ForEach 之间移动时,`LazyVStack` 跨块复用旧 cell 且不更新内容(D2 的实测根因)。改为在单个 `ForEach(Array(model.visibleItems.enumerated()), id: \.element.id)` 内渲染全部行,置顶/最近分区头按行下标条件内联(`index == 0` 且有置顶 → 置顶头;`index == pinned.count` 且有最近 → 最近头)。条目在分区间移动成为同一 ForEach 内的位置变化,SwiftUI 按 id 做 diff 时必然以新值更新行内容。

- *备选:`LazyVStack` 换 `VStack`* —— 消除懒加载缓存复用,但两个 ForEach 的跨块 id 共享仍是非规范结构,治标不治本,不单独采纳。
- *备选:行 identity 加分区前缀(如 `id: \.self` 复合键)* —— 需要改 `ShelfItem` 或引入包装类型,侵入数据层,不符合"SwiftUI 只管内容"的分层,不采纳。
- 分区头内联的边界已覆盖:全部置顶(无最近头)、全部最近(`index == 0 == pinned.count` 渲染最近头)、搜索过滤(头部计数随过滤结果变化,与原行为一致)。

## Risks / Trade-offs

- [`NSApp.keyWindow?.level == .popUpMenu` 在个别 macOS 版本对菜单跟踪判定不成立] → 与鼠标位置信号互为兜底:主场景(菜单覆盖在面板上方)由位置守卫独立覆盖;tasks 中真机验收明确包含"菜单打开停留 >1s 再点击取消置顶"步骤,不通过则回到 D1 补强。
- [菜单会话期间 0.35s 续期造成极短暂的额外 CPU 唤醒] → 仅在菜单打开的数秒内存在,量级可忽略;菜单关闭即收敛。
- [本环境无法运行时复现根因,根因置信度依赖静态分析] → 验收清单(tasks)把两个入口、菜单停留时长、重启持久化全部列为必测项;若真机复现出与 D1 假设不同的现象,以实测为准修订设计后再实施。
- [误伤正常隐藏] → sensor `mouseExited` 0.5s 路径与延时不变,仅加固 work item 生效判定;真机验收覆盖"鼠标离开后面板按时消失"。

## Migration Plan

无数据迁移、无格式变更。回滚策略:还原 `ShelfWindowController.swift` 即可,`shelf.json` 与其他模块不受影响。

## Open Questions

(无——根因置信度与验证路径已在 Risks 中如实记录,不阻塞实施。)

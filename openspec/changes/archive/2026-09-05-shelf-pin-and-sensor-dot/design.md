# Design: 2026-09-05-shelf-pin-and-sensor-dot

## Context

- 传感器是每屏一块透明 `NSPanel`（`level = .statusBar`，常驻 orderFront、不清除），`SensorView` 只有 NSTrackingArea + 拖放接收，**没有任何绘制**；Shelf 的可见性由 `ShelfWindowController` 管理，展开/拖放/peek 三态，隐藏走多个自动路径（鼠标移出 0.5s、Shelf 内移出 0.35s、拖放 peek 0.85s、失 key、确认后延迟 0.6s）与两个显式路径（Esc、动作完成）。
- 设置持久化链路已成熟：`ShelfSettings`（snake_case CodingKey + 容错 `decodeIfPresent ?? 默认值`）→ `AppModel.updateSettings` → `ShelfStoreService.updateSettings` 写 `shelf.json` → `settingsDidChange` 触发各服务刷新。旧 `shelf.json` 缺字段时按默认值解码，无需迁移。
- 服务间联动用闭包接线（`AppDelegate` 里 `settingsDidChange` → `sensors.rebuild()` 等）；项目禁止轮询重建传感器。
- 已知坑：自绘 NSView 不得开 `wantsLayer`（layer 内容不裁剪到 bounds，见 `FloatingPreviewController.swift:418-420` 注释）；Shelf 行内按钮不要用 SwiftUI `Button`（历史交互坑）。

## Goals / Non-Goals

**Goals:**

- 常驻模式以最小侵入接入现有隐藏逻辑：一个汇聚点早退 + 两处调用方早退，不动隐藏时长常量。
- 指示点纯 AppKit 自绘、事件驱动刷新，跨屏状态正确，重建传感器后状态自愈。
- 全部新文案进 zh/en 词典；`static_checks.py` 要求的 API 调用点与禁词不受影响。

**Non-Goals:**

- 不做"常驻但收起为图标条/迷你条"的第三形态。
- 不调整任何既有自动隐藏时长或悬停展开延迟。
- 不给指示点加动画（呼吸、闪烁）。
- 不改变多屏显示目标策略与拖放语义。

## Decisions

### D1. 常驻状态 = `ShelfSettings` 新增 Bool（`shelfKeepOpen`，CodingKey `shelf_keep_open`，默认 false）

理由：需要跨重启持久化并让设置 UI 与 Shelf 开关共享同一事实源；设置管线（持久化 + `settingsDidChange` 广播）现成。备选：运行时全局变量 / 独立存储——无法持久化或需要新存储路径，均否。`init()`、`CodingKeys`、`init(from:)` 三处同步补齐，解码容错保证旧文件兼容。

### D2. 隐藏抑制采用"汇聚点 + 两处早退"，不逐个改调用点

- 汇聚点：`scheduleHide` 开头检查 `model.settings.shelfKeepOpen`，为 true 直接 return——一次性覆盖悬停移出、Shelf 移出、peek 延迟、确认后延迟四类自动隐藏。
- `SensorManager.onMouseExit`：常驻时跳过 `scheduleHide()`（保留 `cancelScheduledExpand` 语义不需要，展开中无所谓，仍保留取消以防空驶）。
- 失 key 观察者：常驻时跳过 `hide()`。
- Esc 与取消图钉走 `requestHide`/`hide()` 直达路径，天然不受汇聚点影响，满足"显式隐藏保留"。取消图钉后再补一次 `hide()`。
- 备选：在每个调用点分散判断——改动面大且容易漏新增路径，否。

### D3. 图钉开关放在 Shelf 头部区域，非条目行

复用 ShelfView 头部已有的轻量操作区模式（`Image(systemName:)` + 点击手势，不用 SwiftUI `Button`）。激活态用 `pin.fill` + 强调色，未激活用 `pin` 弱化色；与条目级 pinned 的区分靠位置（头部 vs 条目行）+ 本地化 tooltip（"常驻展开/取消常驻"）。设置窗口用现有 `settingRow` + `Binding(get:set:)` + `model.updateSettings` 模式加镜像开关。

### D4. 启动展开

`AppDelegate` 完成传感器构建后，若 `shelfKeepOpen == true` 则对显示目标策略选出的屏幕调用 `ShelfWindowController` 展开路径（expanded 态，现有 `show(_:)` 已处理 makeKey；面板为 nonactivating，不会抢走前台应用焦点）。

### D5. 指示点：`SensorView` 普通 `draw(_:)` 自绘，白色 alpha ≈ 0.4、直径 ≈ 5pt

- 位置：触发区内水平居中、距下缘约 4pt——在带刘海屏上落在物理刘海下缘以下的可见带，符合 spec"不被刘海遮挡"。
- 颜色：固定白色低透明度。备选 `NSColor.labelColor` 自适应——菜单栏外观与应用外观可能不一致，且菜单栏背景是壁纸透传，固定白 + 低 alpha 在明暗下均可用；不足再迭代描边，不在本期。
- **不开 `wantsLayer`**（项目坑）；参照 `NativeDragSourceView` 的 alpha 绘制风格。
- 开关：`SensorView` 增加 `showsIndicator: Bool` 标志，变更时 `needsDisplay = true` 重绘。

### D6. 可见性联动：`ShelfWindowController` 暴露 `onVisibilityChange` 闭包 + `isShelfVisible`，`AppDelegate` 接线到 `SensorManager`

- `show(_:)` 立即回调 `false`（有点即无点）；`hide()` 在收起动画完成后回调 `true`，避免点与收起动画重叠闪烁。
- `SensorManager` 保存当前可见性，新建/重建面板时初始化 `showsIndicator = 当前 Shelf 可见`（重建自愈，满足"屏幕变化后状态正确"）。
- 多屏：可见性是全局单值，`setIndicator` 作用于全部传感器，各屏只画自己那份——天然满足"多屏独立"。
- 备选：Notification 广播——项目现有风格是闭包接线，且类型安全，否。

### D7. 本地化

`Localization.swift` zh/en 各加：常驻开关标题（设置行 + tooltip）、指示点相关如需无障碍描述。键名用 `keepShelfOpen` 等，两词典必须同时补齐。

## Risks / Trade-offs

- [常驻 + 展开态 makeKey 可能干扰键盘流] → 面板是 nonactivating，`makeKey` 不激活应用；失 key 后不再重夺 key，仅保持可见。手动验收覆盖"切走再切回"。
- [白色低透明度点在极浅壁纸的菜单栏上偏淡] → 手动验收项；若不可辨再考虑加深描边或自适应色（spec 允许半透明可辨识，属参数微调，不改架构）。
- [hide 动画与回调时序错位导致点闪烁] → 回调固定在动画完成回调里触发；单测不可达，列入手动验收。
- [常驻时用户忘关导致 Shelf 长期占屏] → 属产品预期行为；设置窗口提供镜像开关可随时关闭。

## Migration Plan

无数据迁移：新字段解码默认 false，旧 `shelf.json` 原样兼容；回滚仅需还原代码（旧版本 Codable 忽略未知 key，多出的 `shelf_keep_open` 字段无害）。

## Open Questions

无——点的尺寸/透明度等参数留给手动验收微调，不影响 spec 与任务拆分。

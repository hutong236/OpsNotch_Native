## Why

用户报告:记录置顶后,取消置顶实际不可用("取消置顶没有实现")。Pinned/Recent 是 Shelf 的核心闭环,`VERIFY_ON_MAC.md` §9 明确要求"取消 Pin 回 Recent",该闭环目前只完成了前一半。

代码审查结论:数据层(`ShelfStoreService.setPinned` → 持久化 → `AppModel.togglePin` → `ShelfLogic.grouped` 分组)逻辑正确,8 个 Core 单测全绿,现场 `shelf.json` 中也存在成功置顶并落盘的记录(`pinned: true`)。问题出在 AppKit 交互层:shelf 面板的自动隐藏逻辑(`scheduleHide`,0.35s)在右键上下文菜单打开期间仍会触发 `panel.orderOut`,把正在使用的菜单连同"取消置顶"菜单项一起压掉,用户永远点不到该入口;悬停 `pin.slash` 按钮路径同样被该隐藏时序干扰,需要端到端验证。

说明:本机屏幕录制/辅助功能授权受限,无法在本环境做运行时复现;根因结论来自与运行中实例(dist 2026-08-30 构建,与当前源码一致)一致的代码路径分析,修复后须按 `VERIFY_ON_MAC.md` 在真机做手动验收。

## What Changes

- 修复 `ShelfWindowController.scheduleHide` 的无条件 `orderOut`:隐藏生效前校验鼠标真实位置仍在面板之外,否则重新调度,保证上下文菜单(取消置顶/置顶/编辑/移除)打开期间面板与菜单不被隐藏逻辑打断。
- 端到端验证两个取消置顶入口——悬停操作按钮(`pin.slash` 图标)与右键菜单"取消置顶"——均能将条目移回 Recent 并持久化。
- 补齐 Core 层回归测试:`setPinned(id:, pinned: false)` 的取消置顶落盘与重载行为(当前测试只覆盖排序与 TTL,未覆盖 setPinned 本身)。
- 不新增任何 UI 控件、不改数据模型与 `shelf.json` 格式(假设:用户期望的是让现有两个取消置顶入口可靠生效,而非新增交互方式)。

## Capabilities

### New Capabilities

- `shelf-items`: Shelf 条目(文件/文件夹/URL/文本/应用/动作)的置顶与取消置顶行为——两个操作入口的可用性、分区归属(Pinned ↔ Recent)、落盘持久化、TTL 豁免。

### Modified Capabilities

(无——`openspec/specs/` 下现仅有 `git-repo-config`,本变更不涉及。)

## Impact

- `Sources/OpsNotchApp/ShelfWindowController.swift` — `scheduleHide`/隐藏时序(主要修改点)。
- `Sources/OpsNotchApp/ShelfView.swift` — 预期不改动;仅在验证发现悬停按钮路径缺陷时最小修复。
- `Tests/OpsNotchCoreTests/` — 新增 `setPinned` 取消置顶持久化测试。
- 不影响 `OpsNotchCore` 数据模型、legacy 迁移与 `shelf.json` 兼容性;不触碰 `scripts/static_checks.py` 的 API 调用点约束(不改 `registerForDraggedTypes`、`NSScreen.screens` 等受检调用)。

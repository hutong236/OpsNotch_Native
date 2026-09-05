## Context

应用以 `.accessory` 策略运行（无 Dock 图标），shelf 面板是 `level = .floating` 的 `.nonactivatingPanel`（`ShelfWindowController.swift:33-38`），交互全程不激活应用。两处缺陷都源于这个"从不激活"的前提被对话框打破：

- **添加流程选择面板灰色**：`AppModel.chooseFiles()` / `chooseFolder()` / `chooseApplication()`（`AppModel.swift:437-461`）直接 `NSOpenPanel().runModal()`，全程未激活应用，模态面板呈禁用灰态。对照本仓库正常工作的对话框（`SettingsWindowController.swift:22`、`FinderQuickLauncherWindowController.swift:30`、`InputMethodSettingsView.swift:123-135`）均先 `NSApplication.shared.activate(ignoringOtherApps: true)`。另 `chooseApplication` 用 `UTType(filenameExtension: "app") ?? .application` 做内容类型过滤，属脆弱写法。
- **编辑器不显示**：编辑器是挂在 ShelfPanel 内容上的 SwiftUI `.sheet`（`ShelfView.swift:38-40`）。sheet 窗口夺取 key 时面板触发 `didResignKey`，观察者（`ShelfWindowController.swift:71-81`）无条件 `hide()`，把面板连同 sheet 一并 `orderOut`。同文件已在 `scheduleHide`（:220）和 keyDown 监听（:89）守卫 `model.editorDraft == nil`，唯独 resignKey 观察者遗漏。

在途的 shelf-performance 未提交改动不涉及上述文件中的对话框/sheet 代码，无冲突。

## Goals / Non-Goals

**Goals:**

- 三个 `choose*` 面板在 shelf 场景下可正常选择（补齐激活）。
- 编辑器 sheet 展示期间 shelf 面板不被自动隐藏逻辑收起。
- 修复方式与本仓库既有窗口呈现模式保持一致（激活后再呈现）。

**Non-Goals:**

- 不改条目模型、存储格式、`SafeActionValidator` 校验规则。
- 不重构编辑器呈现方式（不迁移到独立窗口）。
- 不处理状态栏菜单入口以外的添加路径（其复用同一 `editorDraft`/`choose*` 代码，随之修复）。

## Decisions

1. **三处 `choose*` 在 `runModal()` 前调用 `NSApplication.shared.activate(ignoringOtherApps: true)`** — 与 SettingsWindowController 既有模式一致，改动最小且消除根因。备选：改用 `panel.begin { }` 异步呈现——仍需先激活，且会把回调风格引入同步调用链，无额外收益，不采纳。同时修复 `chooseFiles`/`chooseFolder`：用户只报告了「添加应用」，但三处同根因同症状，一并修复并在此记录该假设。
2. **`chooseApplication` 的 `allowedContentTypes` 直接用 `.application`** — 与 `InputMethodSettingsView.swift:130` 现行写法一致，避免 `UTType(filenameExtension:)` 派生失败导致列表全禁用的隐患。
3. **`didResignKey` 观察者补 `guard model.editorDraft == nil`（或等价的"编辑器在展示"判断）** — 与同文件 ：89、:220 两处既有守卫完全同构，不引入新状态。备选：编辑器改用独立浮动窗口承载——改动大、涉及焦点/层级/生命周期新问题，与最小修复原则冲突，不采纳。备选：只豁免 key window 为 sheet 的情况——依赖 sheet 窗口判定细节，不如直接以 `editorDraft` 状态判定稳定。
4. **不主动让应用在面板关闭后"回到非激活态"** — accessory 应用短暂处于激活态无副作用，用户点击其他应用后自然让出；增加反激活逻辑反而引入闪烁。

## Risks / Trade-offs

- [面板弹出时 shelf 因失焦隐藏，面板悬浮在空白处] → 可接受：面板本就应遮住其他内容，选择完成/取消后流程结束；不做额外保持逻辑，避免面板与 shelf 抢焦点。
- [resignKey 守卫放宽后，编辑器打开期间点击面板外不会自动收起 shelf] → 符合规格（编辑态保持可见）；用户取消/保存后既有隐藏行为立即恢复，Esc 键与取消按钮均可退出。
- [`NSApp.activate` 在未来 macOS 版本行为变化] → 本仓库多处已在用同一 API（含 `SMAppService` 相关流程），风险与现状一致，不额外抽象。

## Migration Plan

纯 App 层两文件小改动，无数据迁移；回滚即 revert 两个文件。

## Open Questions

（无——两个根因均已在代码中定位并验证，方案与既有模式对齐。）

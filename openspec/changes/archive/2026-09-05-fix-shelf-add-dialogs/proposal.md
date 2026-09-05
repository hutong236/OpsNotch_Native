## Why

用户报告了 shelf「+」菜单两个添加流程完全不可用：点「添加应用…」弹出的 `NSOpenPanel` 整体呈灰色、无法选择任何条目；点「添加安全操作…」编辑器界面完全不显示。添加条目是 shelf 的核心入口，这两个入口失效意味着用户无法手工补充应用与安全操作条目。

## What Changes

- 修复「添加应用/文件/文件夹」`NSOpenPanel` 灰色不可选：三个 `choose*` 方法在 `runModal()` 前缺少 `NSApp.activate(ignoringOtherApps: true)`（应用以 `.accessory` + `.nonactivatingPanel` 运行，面板在不激活的应用里呈禁用态）；`chooseApplication` 的内容类型过滤改用 `.application`，替换脆弱的 `UTType(filenameExtension: "app")` 派生。
- 修复「添加安全操作…」（以及共用同一 sheet 的新建文字/网址/编辑）编辑器不显示：sheet 夺取 key 时 `ShelfPanel` 的 `didResignKey` 观察者无条件 `hide()`，把面板连同 sheet 一起收起；为该观察者补上与 `scheduleHide`、keyDown 监听一致的 `editorDraft == nil` 守卫。
- 不改变任何持久化格式、条目模型或安全校验逻辑（`SafeActionValidator.validate` 行为不变）。

## Capabilities

### New Capabilities

- `shelf-add-item-dialogs`: 通过 shelf「+」菜单添加条目时对话框/编辑器的行为约束——应用未激活场景下 open panel 必须可交互；编辑器 sheet 展示期间 shelf 面板必须保持可见。

### Modified Capabilities

（无——现有 specs 均不覆盖添加条目对话框路径，`shelf-items` 只涉及 unpin 行为。）

## Impact

- `Sources/OpsNotchApp/AppModel.swift`：`chooseFiles()` / `chooseFolder()` / `chooseApplication()` 三处前置激活 + 应用内容类型修正。
- `Sources/OpsNotchApp/ShelfWindowController.swift`：`didResignKey` 观察者补 `editorDraft == nil` 守卫。
- 无 Core 层、存储格式、API 变更；`scripts/static_checks.py` 要求的 API 调用点均不涉及。
- 与在途的 shelf-performance 未提交改动无文件交集（其未触碰 `ShelfView.swift` / `ShelfWindowController.swift` / 对话框代码）。

# Design: Unified Quick Shelf

## 设计原则

1. 保留现有架构边界：AppKit 负责窗口、Finder、Pasteboard；SwiftUI 负责内容展示。
2. 不复制 Finder 能力，复用 `FinderWindowService`、`FinderQuickPathRanking` 与现有设置。
3. 不改变 `ShelfItem` 和 `shelf.json`，统一入口仅为展示/交互层组合。
4. 文件取回继续复用 `ShelfLogic.copyPayload` + `ClipboardManager.copyPayload`，保证 file URL pasteboard flavor 不退化。

## 统一条目模型

在 App 层新增轻量 `QuickShelfEntry`：

- `finder`: 默认路径或收藏 Finder 路径
- `shelf`: 现有 `ShelfItem`

每个条目使用稳定字符串 ID：

- `finder:default`
- `finder:<UUID>`
- `shelf:<UUID>`

`AppModel.highlightedQuickEntryID` 代替仅面向 Shelf UUID 的键盘高亮状态。

## 展示顺序

1. Finder Quick Paths
2. Pinned
3. Recent

Finder 默认路径固定首位；收藏使用 `FinderQuickPathRanking.ranked()`。

## 搜索与筛选

- Finder：名称、展开后的实际路径参与大小写不敏感匹配。
- Shelf：继续使用 `ShelfLogic.grouped`。
- Finder 分区只在 `.all` 与 `.file` 筛选下可见。
- 搜索/筛选改变后，高亮回落到新的第一项。

## 键盘执行

- ↑/↓：在 `visibleQuickEntries` 中移动。
- Enter：
  - Finder → 调用注入的 Finder 打开回调。
  - Shelf → `ShelfLogic.copyPayload` → `ClipboardManager.copyPayload`。
- Space：只有高亮为 Shelf 且可预览时 Quick Look。
- Esc：收起。

## Finder 打开

`UnifiedFinderCoordinator` 位于 AppKit/App 层，持有 `FinderWindowService` 并由 `AppDelegate` 向 `AppModel` 注入 Finder 打开回调。执行 Finder 条目时先收起统一 Shelf，再使用当前 Finder 打开模式打开目录；成功打开收藏路径后更新 useCount / lastUsedAt，失败沿用现有提示。

## Finder 兼容快捷键

`FinderRevealController` 不再创建独立 Finder Launcher 作为主要 UI。它接收统一 Shelf 的 summon 回调：

- Finder 兼容热键触发 → 清除临时搜索与类型筛选 → 打开统一 Quick Shelf
- 高亮优先设为 `finder:default`

保留设置字段和 Carbon 热键注册方式，不破坏历史配置。

## 鼠标交互

Finder 行：

- 单击：打开目录
- 复制按钮 / 右键：复制展开后的路径

Shelf 行保持现有按钮、右键和拖拽行为。

## 风险控制

- 不删除旧 Finder Window Service。
- 不修改 ClipboardManager 的捕获和二次复制逻辑。
- 不新增辅助功能/Input Monitoring 权限。
- 旧 Finder Launcher 类暂时保留为未使用兼容代码，后续可单独清理，降低本次回归范围。
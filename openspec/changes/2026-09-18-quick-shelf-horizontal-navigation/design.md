# Design

## 键盘事件层

`ShelfWindowController` 继续作为 macOS 键盘事件入口，在现有 ↑(126)、↓(125)、Enter、Esc 等键位之外增加：

- ← keyCode 123 → `.left`
- → keyCode 124 → `.right`

事件只在 Shelf 面板为 key window、Presentation 为 expanded 且编辑器未打开时消费，与现有键盘流边界一致。

## 导航语义

新增 Core 纯逻辑 `QuickShelfKeyboardNavigation`，从调用方提供的当前可见 ID 中选择目标：

- left：`recentEntryIDs.first`
- right：`finderEntryIDs.first`
- 对应数组为空：返回 nil

AppModel 分别使用 `grouped.recent` 与 `visibleFinderEntries` 映射 ID，因此 Core 不依赖 AppKit/SwiftUI，同时导航语义可单元测试。

## 最新复制记录

`grouped.recent` 已通过 `SmartShelfRanking.ordered` 排序；当前规则固定最新创建的可见条目在首位。因此普通“复制 → 捕获 → 呼出 → ←”流程会落在最新复制记录。

## 搜索与筛选

左右键只在当前可见集合中跳转。若搜索词或 kindFilter 让目标区域为空，则保持当前高亮，不主动清空搜索或改变筛选。

## 焦点

Quick Shelf 展开后搜索框可以保持 first responder。左右键由 Shelf 本地 key monitor 优先消费，用于跨区导航，不泄漏到前台应用。

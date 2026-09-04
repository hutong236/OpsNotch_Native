# Proposal: 统一 Finder 快捷路径与 Quick Shelf

## 背景

当前 Finder 快捷路径与 Shelf/剪贴板取回使用两套独立入口。用户需要先判断内容类型，再选择对应快捷键和面板，增加了记忆和切换成本。

## 目标

将 Finder 快捷目录、Pinned、Recent 与剪贴板历史统一到同一个 Quick Shelf 中：

`统一快捷键 → Quick Shelf → 搜索/↑↓ → Enter`

其中 Finder 目录继续保留原有快速打开能力，Shelf 条目继续保留正确的系统剪贴板语义。

## 范围

- Quick Shelf 顶部加入 Finder 快捷目录分区。
- 默认路径始终第一项；收藏目录沿用现有使用频率/最近使用排序。
- 搜索同时匹配 Finder 名称/路径与 Shelf 内容。
- ↑/↓ 在 Finder、Pinned、Recent 之间连续移动并自动滚动。
- Enter 对 Finder 行执行打开目录；对 Shelf 行执行现有复制取回。
- Finder 独立旧快捷键作为兼容入口，改为打开同一个 Quick Shelf 并优先定位 Finder 首项。
- 保留 Finder 打开模式（系统默认 / 优先 Tab）。
- Finder 行支持鼠标打开和复制路径。

## 非目标

- 不实现自动发送 Cmd+V 或其他键盘注入。
- 不执行 shell、SSH、kubectl 等任意命令。
- 不修改 shelf.json 的持久化格式。

## 验收

以 GitHub Issue #21 的验收标准为准，并通过现有 CI 与 macOS 真机清单。
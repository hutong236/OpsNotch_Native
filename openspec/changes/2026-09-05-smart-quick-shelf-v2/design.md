# Design: Smart Quick Shelf V2

## 设计原则

1. Core 层负责纯逻辑：语义识别、上下文亲和度、SmartScore、Working Set 数据兼容。
2. AppKit 只负责 macOS 系统上下文：前台 App、最近文档/有边界目录候选、Finder/Quick Look/Pasteboard。
3. SwiftUI 负责展示，不在 View 内实现排序算法。
4. 文件复制必须继续复用现有 copy payload，不从 display string 反推文件。
5. 所有智能行为可解释、可回退；没有上下文时退回 recency/frequency 主导排序。

## 数据模型

### ShelfItem
新增：
- `useCount: UInt64` → `use_count`
- `lastUsedAt: UInt64` → `last_used_at`

旧 JSON 缺失字段时均为 0。

### ShelfSettings
新增：
- `workingSetItemIDs: [UUID]` → `working_set_item_ids`

读取时自动去重，并在 AppModel reload/apply 后过滤不存在的 item id。

## SemanticKind

Core 新增轻量语义类型：

- `file`
- `folder`
- `application`
- `url`
- `ipv4`
- `ssh`
- `command`
- `path`
- `text`
- `action`

识别顺序避免误判：显式 ShelfKind → URL → SSH → IPv4 → path → command → text。

命令识别只做模式匹配：常见前缀如 `kubectl`、`docker`、`git`、`ssh`、`ping`、`curl`、`scp`、`rsync`、`helm`、`terraform`、`ansible`、`systemctl`、`journalctl`、`brew`、`npm`、`python` 等；绝不执行。

## AppContext

App 层使用 `NSWorkspace.shared.frontmostApplication` 获取 bundle id/name，映射为：

- finder
- terminal
- browser
- generic

终端集合至少覆盖 Terminal、iTerm2、Warp、Alacritty、kitty、WezTerm；浏览器覆盖 Safari、Chrome、Edge、Firefox、Arc。

## SmartScore

Core 评分函数输入：ShelfItem、SemanticKind、query、AppContextKind、now。

建议权重：

- query exact/prefix/contains：最高优先级，确保搜索正确性。
- pinned / working set：由分区保证强优先，不依赖单一分数。
- recency：指数/分段衰减。
- useCount：对数或封顶增长，避免老条目永久霸榜。
- lastUsedAt：最近取回加权。
- app context affinity：Finder→file/folder/path；Terminal→command/ssh/ipv4/path；Browser→url/text。
- stable tie-break：updatedAt、createdAt、UUID。

## Quick Shelf 分区

展示顺序：

1. Finder Quick Paths
2. Working Set
3. Pinned
4. Smart Recent / Search Results
5. Local File Results（仅有 query 时，可与结果区合并展示）

Working Set 与 Pinned 都引用原 ShelfItem；同一 item 在 Working Set 中出现时不应再在 Recent 重复显示。Pinned + Working Set 的重叠优先显示在 Working Set。

## Working Set 操作

AppModel 提供：
- `isInWorkingSet(_:)`
- `toggleWorkingSet(_:)`
- `clearWorkingSet()`
- `workingSetItems`

持久化使用 `updateSettings`。删除/过期 item 后自动清理无效 ID。

## 使用频率

`ShelfStoreService.recordUse(id:)` 在一次成功的默认取回动作后：
- `useCount &+= 1`
- `lastUsedAt = now`
- `updatedAt = now`（维持 V1 最近使用上浮行为）

## 本地文件/目录搜索

新增 `LocalFileSearchService`，只在 query 非空且文件筛选允许时工作，并设置严格上限：

1. `NSDocumentController.shared.recentDocumentURLs`。
2. 当前 Shelf 文件/目录的父目录。
3. Finder 默认路径与收藏路径的第一层 children。

规则：
- 每个根目录最多读取固定数量条目。
- 总结果最多 20。
- 不递归。
- 去重标准化路径。
- 不触发额外权限申请。

结果作为临时 QuickShelfEntry，不进入 shelf.json。

## 键盘与默认动作

- ↑/↓：所有可见 QuickShelfEntry 统一导航并滚动。
- Enter：Finder/local folder → Finder 打开；Shelf/local file → 正确 file URL copy；text/url → 复制文本。
- Space：Shelf/local file 可 Quick Look。
- Esc：关闭。

## 风险控制

- 不执行识别到的命令。
- 不保存前台 App 历史，只保存当前运行态 context。
- 不读取 shell history/browser history/keychain。
- LocalFileSearchService 不递归。
- 新字段均带默认值并补 Core migration/compat tests。

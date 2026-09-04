# Proposal: Smart Quick Shelf V2 (v2.3.0)

## 背景

v2.2.13 已将 Finder 快捷路径与剪贴板/Shelf 统一进一个 Quick Shelf。V2 的目标不是增加更多独立模块，而是让这个统一入口具备“理解当前工作场景”的能力：知道用户当前在 Finder、终端还是浏览器，理解 Shelf 中是 IP、SSH、命令、URL、路径还是普通文本，并结合最近使用、使用频率和 Working Set 给出更合理的顺序。

## 目标

将 Quick Shelf 升级为上下文感知的运维工作台：

`统一入口 → 当前 App 上下文 → 语义识别 → 智能排序 → Working Set / 搜索 → Enter 执行安全默认动作`

## 范围

- 本地识别 IPv4 / URL / SSH / command / path / text。
- 读取前台 App 的 bundle id/name 并映射为 Finder / terminal / browser / generic 上下文。
- 引入可测试、可解释的 SmartScore 排序模型。
- ShelfItem 增加 useCount / lastUsedAt，旧数据缺字段时默认 0。
- ShelfSettings 增加 workingSetItemIDs，旧数据默认空数组。
- Working Set 显示在 Finder 与 Pinned/Recent 之间，支持加入、移除、清空和重启恢复。
- Query 搜索相关性优先于 App 上下文。
- 文件/目录搜索增加有边界的本地候选，不进行全盘递归扫描。
- 继续保留 V1 的 Finder 打开、Quick Look、键盘导航和 file URL pasteboard 语义。

## 非目标

- 不自动执行 shell / ssh / kubectl / docker / git。
- 不自动发送 Cmd+V。
- 不读取终端历史、浏览器历史、钥匙串。
- 不新增 Accessibility / Input Monitoring 权限。
- 不实现无界 Spotlight 或全磁盘索引服务。

## 兼容性

本次仅增加带默认值的 Codable 字段，不破坏旧 `shelf.json`。文件取回继续走 `ShelfLogic.copyPayload` + `ClipboardManager.copyPayload`，确保 Finder 中仍粘贴为真实文件。

## 验收

以 GitHub Issue #23 与本变更下的 Specification 为准。目标发布版本为 `v2.3.0`。

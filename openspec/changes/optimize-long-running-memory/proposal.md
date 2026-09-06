## Why

Ops Notch 是常驻型 macOS 工具，用户可能连续运行数天。现有实现虽然已经限制 Shelf 条目数量并减少磁盘 I/O，但仍有两类不必要的长期资源占用：ClipboardManager 为 1 秒去重保留上一份完整剪贴板内容；本地文件搜索在快速输入时会连续创建 detached 搜索，而调用方取消不会自动停止已启动的 detached 工作。

## What Changes

- 剪贴板短时去重改为固定大小内容指纹，不再额外保留上一份完整大文本或完整路径数组。
- 保持现有 100ms/400ms changeCount 轮询策略，避免改变连续复制捕获语义。
- 本地文件搜索增加短 debounce，连续输入时不为每个字符都启动目录扫描。
- 将调用方取消显式传递给 detached 搜索，并在目录遍历阶段检查取消，尽快释放旧查询占用的临时集合与文件系统工作。

## Impact

- 不修改 shelf.json 格式、Shelf 条目上限、TTL、剪贴板历史内容或 Finder 搜索范围。
- 不增加权限，不增加新的常驻监听器。
- 主要影响 `ClipboardManager.swift` 与 `LocalFileSearchService.swift`。

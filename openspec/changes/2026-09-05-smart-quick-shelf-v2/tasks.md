# Tasks

- [x] 创建 V2 Epic / Issue #23。
- [x] 创建 `feature/smart-quick-shelf-v2` 开发分支。
- [x] 完成 proposal / design / specification。
- [x] Core：ShelfItem 增加 useCount / lastUsedAt，保持旧 JSON 兼容。
- [x] Core：ShelfSettings 增加 workingSetItemIDs，保持旧 JSON 兼容。
- [x] Core：新增 SemanticKind 与本地识别器。
- [x] Core：新增 AppContextKind / SmartScore 排序逻辑。
- [x] Core：ShelfStoreService 增加 recordUse，并在删除/过期时清理 Working Set。
- [x] Core Tests：语义识别、评分、数据兼容、Working Set、recordUse。
- [x] App：前台 App 上下文检测（Finder / terminal / browser / generic）。
- [x] App：有边界 LocalFileSearchService。
- [x] AppModel：Working Set 分区与智能 Recent 排序。
- [x] AppModel：local file/folder 临时结果进入统一 QuickEntry 导航。
- [x] UI：Working Set 分区、加入/移除/清空操作。
- [x] UI：语义类型轻量 badge/icon。
- [x] UI：Local file/folder 搜索结果与默认动作。
- [x] Keyboard：↑/↓、Enter、Space 跨全部 V2 分区保持一致。
- [x] Regression：文件二次取回保持 file URL pasteboard 语义。
- [x] 更新中英文文案与 `VERIFY_ON_MAC.md`。
- [x] `swift test` 通过。
- [x] `swift build` 通过。
- [x] `python3 scripts/static_checks.py` 通过。
- [x] 创建 PR #24 并通过 GitHub Actions。

## CI 记录

- CI #40：V2 主功能代码 `swift test` / `swift build` / Architecture checks 全部通过。
- CI #50：仅新增测试夹具发生 `UInt64` 常量下溢，功能代码无编译错误；已修正测试时间基准。
- CI #51：修正后的 Core tests / Debug build / Architecture checks 全部通过。
- CI #52：Working Set 轻量持久化优化后，Core tests / Debug build / Architecture checks 全部通过。
- 本文件为收尾文档提交；PR 最新提交继续由 CI 自动复验。

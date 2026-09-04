# Tasks

- [x] 创建 Issue #21 与需求说明。
- [x] 完成 proposal / design。
- [x] 新增统一 QuickShelfEntry 展示模型。
- [x] 将 Finder 快捷路径注入 Quick Shelf 顶部分区。
- [x] 搜索同时覆盖 Finder 与 Shelf。
- [x] 统一 ↑/↓ 高亮与自动滚动。
- [x] Enter 按条目类型执行 Finder 打开或 Shelf 复制取回。
- [x] Finder 行增加鼠标打开与复制路径。
- [x] Finder 兼容热键改为召唤统一 Quick Shelf。
- [x] 更新设置说明与中英文文案。
- [x] 更新 VERIFY_ON_MAC.md。
- [x] 评估 Core 测试：本次组合逻辑位于 App 展示/系统交互层，未改变 Core 排序、存储或复制 payload，因此沿用既有 Core + Pasteboard 回归测试，不新增重复测试。
- [x] GitHub Actions 运行 `swift test` 通过。
- [x] GitHub Actions 运行 `swift build` 通过。
- [x] GitHub Actions 运行 `python3 scripts/static_checks.py` 通过。
- [x] 创建 PR #22 并核对 CI。

## CI 记录

- CI #28：Core tests / Debug build / Architecture checks 全部 success。
- 后续仅文档/设置说明提交继续由 PR CI 复验。
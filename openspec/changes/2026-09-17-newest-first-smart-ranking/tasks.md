# Tasks

- [x] 定义“最新加入优先，其余智能排序”的行为边界。
- [x] Core：`SmartShelfRanking.ordered` 在过滤后保留 `createdAt` 最新条目为首位。
- [x] Core：首位之外继续复用原 SmartScore 排序。
- [x] Core Tests：覆盖高分旧条目、最近使用旧条目、同秒加入、首位后 SmartScore、query relevance。
- [x] UI：更新中英文排序提示文案。
- [ ] `swift test` 通过。
- [ ] `swift build` 通过。
- [ ] `python3 scripts/static_checks.py` 通过。
- [ ] GitHub Actions 通过。

# Smart Quick Shelf: Horizontal Section Navigation

## Requirement: 右方向键进入快捷目录

系统 MUST 在 Quick Shelf 展开并处于键盘会话时，将 → 映射到当前可见 Finder 快捷目录的第一项。

### Scenario: 快捷目录存在
- GIVEN Finder 快捷目录存在至少一个当前可见条目
- WHEN 用户按 →
- THEN 第一条 Finder 快捷目录 MUST 成为当前高亮项
- AND Shelf MUST 保持展开

### Scenario: 快捷目录不可见
- GIVEN 当前搜索或类型筛选导致 Finder 快捷目录为空
- WHEN 用户按 →
- THEN 当前高亮 MUST 保持不变

## Requirement: 左方向键进入智能最近首条

系统 MUST 将 ← 映射到当前可见“智能最近”的第一项。

### Scenario: 刚复制内容
- GIVEN 剪贴板捕获产生一条新的非置顶 Recent 条目
- AND 该条目是当前可见 Recent 中最新创建的条目
- WHEN 用户呼出 Quick Shelf 并按 ←
- THEN 最新复制条目 MUST 成为当前高亮项

### Scenario: 智能最近为空
- GIVEN 当前可见“智能最近”为空
- WHEN 用户按 ←
- THEN 当前高亮 MUST 保持不变

## Requirement: 保持现有键盘行为

系统 MUST 保持 ↑ / ↓、Enter、Esc、Tab、Command+数字筛选与 Space Quick Look 的现有语义，不因新增左右导航而改变剪贴板或持久化数据。

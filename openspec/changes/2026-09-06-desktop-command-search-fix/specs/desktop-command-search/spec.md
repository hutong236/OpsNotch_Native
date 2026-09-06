# Spec: Desktop Command Search

## Requirements

### Desktop 命令不得自动执行
系统 MUST NOT 因 query 匹配 Desktop 命令而自动切换 Space 或弹出桌面列表。

### Desktop 命令必须作为统一搜索候选
当 query 精确匹配 `d`、`desktop`、`桌面` 或显式的空格编号命令时，系统 MUST 在统一结果列表顶部生成 Desktop 候选。

### 编号命令必须使用分隔空格
系统 MUST 接受 `d 1`、`d 2`、`desktop 3`、`桌面 4`；MUST NOT 将 `d1`、`d2` 解析为 Desktop 命令。

### 普通搜索不得被 Desktop 功能抢占
`ddd`、`docker`、`desktop app` 等普通查询 MUST 按现有统一搜索逻辑继续工作。

### 执行必须由用户确认触发
Desktop 候选 MUST 支持方向键高亮，并仅在 Enter 或鼠标点击后调用 Desktop Space 切换能力。

### 底层 Space 行为保持不变
本变更 MUST NOT 回退 #29 的 Display/Space 拓扑、Dock gesture、HID fallback、焦点恢复和鼠标恢复能力。

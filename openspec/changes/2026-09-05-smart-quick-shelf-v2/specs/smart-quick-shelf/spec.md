# Smart Quick Shelf V2 Specification

## Requirement: 本地语义识别

系统 MUST 在本地识别 Shelf 内容的语义类型，且识别结果不得触发执行。

### Scenario: IPv4
- GIVEN Shelf 文本为 `192.168.10.40`
- WHEN 计算语义类型
- THEN 类型为 `ipv4`

### Scenario: SSH
- GIVEN Shelf 文本为 `ssh admin@192.168.10.40`
- WHEN 计算语义类型
- THEN 类型为 `ssh`
- AND 系统不执行该命令

### Scenario: Command
- GIVEN Shelf 文本以 `kubectl` / `docker` / `git` 等已知命令前缀开始
- WHEN 计算语义类型
- THEN 类型为 `command`

### Scenario: Path
- GIVEN 文本为 `/Users/me/project/config.yaml` 或 `~/Downloads`
- WHEN 计算语义类型
- THEN 类型为 `path`

## Requirement: 前台 App 上下文

系统 MUST 使用当前前台 App 构建一次性的 AppContext，不持久化 App 使用历史。

### Scenario: Finder
- WHEN Finder 是前台应用
- THEN context 为 `finder`
- AND file/folder/path 具有正向上下文亲和度

### Scenario: Terminal
- WHEN Terminal / iTerm / Warp 等终端是前台应用
- THEN context 为 `terminal`
- AND command/ssh/ipv4/path 具有正向上下文亲和度

### Scenario: Browser
- WHEN Safari / Chrome / Edge / Firefox / Arc 是前台应用
- THEN context 为 `browser`
- AND url/text 具有正向上下文亲和度

## Requirement: SmartScore

系统 MUST 使用 query relevance、recency、frequency、lastUsedAt 和 app-context affinity 计算智能分数。

### Scenario: Query 优先
- GIVEN query 精确匹配条目 A，前台 App 更偏好条目 B
- WHEN 排序
- THEN A MUST 排在明显不相关的 B 前面

### Scenario: 无 Query
- GIVEN query 为空
- WHEN 两个条目类型相同
- THEN 最近使用与使用次数应共同影响顺序

## Requirement: Working Set

系统 MUST 支持持久化 Working Set，并且只保存 Shelf item ID。

### Scenario: 加入工作集
- WHEN 用户将一个 Shelf item 加入 Working Set
- THEN其 ID 写入 `working_set_item_ids`
- AND 条目显示在 Working Set 分区
- AND 不复制或修改原 payload

### Scenario: 重启恢复
- GIVEN Working Set 已持久化
- WHEN 应用重启并 reload
- THEN仍存在且仍有效的 item 恢复到 Working Set

### Scenario: 删除清理
- GIVEN Working Set 中某 item 被删除或 TTL 过期
- WHEN模型 reload/apply
- THEN无效 ID 从 Working Set 清理

## Requirement: 使用频率

系统 MUST 在 Shelf 默认取回动作成功后记录使用次数和最近使用时间。

### Scenario: 文件取回
- GIVEN Shelf 文件高亮
- WHEN Enter 成功复制 file URL payload
- THEN `use_count` 增加
- AND `last_used_at` 更新
- AND Finder 中仍可粘贴为真实文件

## Requirement: 有边界文件搜索

系统 MUST 在 query 非空时提供额外文件/目录候选，并且不得全盘递归扫描。

### Scenario: 搜索最近文件
- GIVEN query 命中 recentDocumentURLs 中的文件
- WHEN Quick Shelf 搜索
- THEN显示临时文件候选
- AND候选不写入 shelf.json

### Scenario: 浅层目录匹配
- GIVEN Finder 收藏目录下第一层存在匹配名称
- WHEN搜索
- THEN可显示该文件/目录
- AND不得继续递归子目录

### Scenario: 数量限制
- WHEN候选很多
- THEN总结果 MUST 被固定上限截断

## Requirement: 统一导航

系统 MUST 在 Finder、Working Set、Pinned、Smart Recent 和 Local Results 间连续键盘导航。

### Scenario: 跨分区下移
- WHEN用户持续按 ↓
- THEN高亮连续跨越所有可见分区
- AND当前条目自动滚入可视区域

## Requirement: 安全边界

系统 MUST NOT 因 V2 语义识别增加命令执行、自动粘贴或额外隐私读取。

### Scenario: 识别命令
- WHEN识别到 shell/ssh/kubectl/docker/git 文本
- THEN只显示类型/排序/搜索信息
- AND不执行命令
- AND不读取 shell history
- AND不请求 Accessibility/Input Monitoring 权限

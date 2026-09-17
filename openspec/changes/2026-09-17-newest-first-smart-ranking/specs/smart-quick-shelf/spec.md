# Smart Quick Shelf: Newest First

## Requirement: 最新加入优先

系统 MUST 在当前 query 和 kindFilter 过滤后的 Shelf 集合中，将最新创建的条目固定在智能排序结果首位。

### Scenario: 新内容优先于高分旧内容
- GIVEN 条目 A 刚创建，条目 B 更符合当前 App、使用频率更高且最近使用
- WHEN 计算智能排序
- THEN A MUST 排在 B 前面

### Scenario: 使用旧内容不改变“最新加入”
- GIVEN 条目 A 创建时间早于条目 B
- AND A 的 `updatedAt` / `lastUsedAt` 因最近使用而晚于 B
- WHEN 计算智能排序
- THEN B MUST 仍排在首位

### Scenario: 搜索和类型筛选仍生效
- GIVEN 最新创建条目不匹配当前 query 或 kindFilter
- WHEN 计算智能排序
- THEN 该条目 MUST NOT 出现在结果中
- AND 应从匹配后的可见集合中选择最新条目作为首位

### Scenario: 同秒加入
- GIVEN 两条记录具有相同 `createdAt`
- AND 后一条位于 Store 输入数组更靠后的位置
- WHEN 计算智能排序
- THEN 后一条 MUST 作为最新加入项排在首位

## Requirement: 其余条目继续智能排序

系统 MUST 在最新加入条目之外继续使用现有 SmartScore 规则，不修改 query relevance、当前 App、语义、recency、frequency 和 lastUsedAt 的评分逻辑。

### Scenario: 首位之后保持原 SmartScore
- GIVEN 最新加入条目已固定在第一位
- AND 剩余条目中命令条目比普通文本更符合 Terminal 上下文
- WHEN 计算智能排序
- THEN 命令条目 SHOULD 排在普通文本前面

### Scenario: 搜索相关性继续生效
- GIVEN 最新加入条目已固定在第一位
- AND 剩余条目 A 精确匹配 query，条目 B 仅前缀或包含匹配但环境分更高
- WHEN 计算智能排序
- THEN A MUST 排在 B 前面

## Requirement: 排序提示文案

系统 MUST 在中英文界面中说明“最新加入优先，其余智能排序”。

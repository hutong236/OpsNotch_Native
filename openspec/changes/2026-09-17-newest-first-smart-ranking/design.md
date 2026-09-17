# Design

## 排序流水线

`SmartShelfRanking.ordered` 继续先执行 query / kindFilter 过滤，然后把排序拆成两段：

1. 从过滤结果中选出 `createdAt` 最大的条目，固定为第一项。
2. 对其余条目继续执行原有 SmartScore 预计算和排序。

这样不会调整现有评分权重，也不会让“最近使用”覆盖“最新加入”的含义。

## 时间字段选择

使用 `createdAt` 识别最新加入项。`updatedAt` 会在条目使用、编辑或重复捕获时变化，`lastUsedAt` 明确表示最近使用，因此二者都不能作为最新加入的依据。

`createdAt` 为秒级时间戳。同秒创建时以过滤后数组中靠后的元素为最新；新 Shelf 条目由 Store 追加到数组尾部，因此该规则能够保持用户感知的插入顺序。

## 搜索与筛选

先筛选，再保留最新项。这意味着首位条目仍必须匹配当前 query 和 kindFilter；它不会绕过过滤条件。首位之后，query relevance 仍按原有分值层级优先于 App/语义/频率等环境信号。

## 兼容性

不新增持久化字段，不修改 JSON schema，不改变 `score` API，也不改变安全动作和剪贴板语义。

# Unified Quick Shelf Specification

## Requirement: 单一入口展示 Finder 与 Shelf

系统 MUST 在统一 Quick Shelf 中同时展示 Finder 快捷路径与 Shelf 条目。

### Scenario: 默认展示
- GIVEN 用户打开 Quick Shelf
- WHEN 当前筛选为“全部”
- THEN Finder 默认路径显示在 Finder 分区第一行
- AND 收藏 Finder 路径按现有排名规则展示
- AND Pinned/Recent 继续显示在 Finder 分区之后

## Requirement: 统一搜索

系统 MUST 使用同一个搜索框匹配 Finder 与 Shelf 内容。

### Scenario: 搜索 Finder 路径
- GIVEN 用户输入 Finder 收藏名称或路径的一部分
- WHEN 搜索条件命中
- THEN 对应 Finder 路径显示

### Scenario: 搜索 Shelf 内容
- GIVEN 用户输入 Shelf 标题或内容
- WHEN 搜索条件命中
- THEN 对应 Shelf 条目按现有 ShelfLogic 规则显示

## Requirement: 类型筛选

Finder 路径 MUST 只在“全部”和“文件”筛选下显示。

### Scenario: 文本筛选
- WHEN 用户切换到“文本”
- THEN Finder 路径不显示

## Requirement: 连续键盘导航

系统 MUST 在 Finder、Pinned、Recent 的所有可见条目间提供连续 ↑/↓ 导航。

### Scenario: 跨分区移动
- GIVEN Finder 分区有可见项且 Recent 有可见项
- WHEN 用户持续按 ↓
- THEN 高亮从 Finder 最后一项继续移动到后续 Shelf 项
- AND 当前高亮始终滚入可视区域

## Requirement: 上下文 Enter

系统 MUST 按高亮条目类型执行正确动作。

### Scenario: Finder 路径
- GIVEN 高亮为 Finder 路径
- WHEN 用户按 Enter
- THEN 使用当前 Finder 打开模式打开该目录
- AND 收藏路径成功后更新使用次数与最近使用时间

### Scenario: Shelf 文件
- GIVEN 高亮为 Shelf 文件
- WHEN 用户按 Enter
- THEN 写入文件 URL pasteboard payload
- AND 文件不能退化为路径或文件名字符串

### Scenario: Shelf 文本
- GIVEN 高亮为 Shelf 文本
- WHEN 用户按 Enter
- THEN 写入文本 pasteboard payload

## Requirement: Finder 兼容快捷键

历史 Finder 专用热键 MUST 保持可用，但触发统一 Quick Shelf。

### Scenario: 使用旧 Finder 热键
- WHEN 用户按已配置的 Finder 快捷键
- THEN 打开统一 Quick Shelf
- AND 优先高亮 Finder 默认路径
- AND 不再要求用户进入第二套独立路径面板

## Requirement: 不引入额外系统权限

本变更 MUST NOT 通过全局事件监控或自动键盘注入实现自动粘贴。

### Scenario: 使用统一入口
- WHEN 用户使用 Quick Shelf
- THEN 不新增 Input Monitoring 权限要求
- AND 不执行任意 shell/SSH/kubectl 命令
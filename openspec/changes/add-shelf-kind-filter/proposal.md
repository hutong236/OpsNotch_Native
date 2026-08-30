## Why

Quick Shelf 的条目积累到几十条以上时,单列从上到下滚动定位成本很高;现有搜索只能按关键词匹配标题/内容,"我记得是个文件但忘了叫什么"这类场景无法快速收窄。同时键盘取回流(`add-hotkey-summon`)已就绪,筛选能力需要与键盘流打通而不是只有鼠标路径。

## What Changes

- 搜索栏下方新增类型筛选 chips:全部 / 文件 / 文本 / URL / 应用。
- 归类规则覆盖全部 6 种条目类型:`file`、`folder`、action(openPath)归入"文件";`url`、action(openURL)归入"URL";`text` 归入"文本";`application` 归入"应用"。
- 筛选与搜索词叠加生效(AND 关系);筛选无结果时显示"没有匹配的条目"空态(与真正空柜区分)。
- 键盘支持:⌘1~⌘5 切换五个筛选位;筛选或搜索变化后键盘高亮回落到过滤结果首行;Space 对键盘高亮的可预览条目(文件/图片等)触发 Quick Look,搜索框聚焦时 Space 仍为普通输入。
- 新增条目(拖入/剪贴板捕获/手动添加)被当前筛选隐藏时,筛选自动回到"全部",避免用户看不到刚放入的条目。
- 筛选状态仅会话内有效,不持久化,不改动 `shelf.json` 存储格式与设置项。
- `Localization.swift` 新增 zh/en 双语文案。

## Capabilities

### New Capabilities

- `shelf-kind-filter`: 按类型筛选 Shelf 条目的完整行为闭环——chips 归类规则、与搜索叠加、键盘(⌘1~⌘5 / 高亮回落 / Space 预览)、新增条目回退"全部"、空态与会话内生效范围。

### Modified Capabilities

(无——置顶、预览、热键呼出等既有能力的需求不变。)

## Impact

- **Core**(`Sources/OpsNotchCore/`):`ShelfLogic.swift` 新增 `ShelfKindFilter` 类型与过滤参数(带默认值,既有调用点与迁移测试不受影响);保持 UI/AppKit-free,可单测。
- **App**(`Sources/OpsNotchApp/`):`AppModel` 持有筛选状态与高亮回落逻辑;`ShelfView` 新增 chips 行、高亮样式、无结果空态;`ShelfWindowController` 扩展现有 `keyMonitor`(⌘数字、Space)。
- **依赖关系**:⌘1~⌘5 与 Space 依赖 `add-hotkey-summon` 已落地的面板 key 窗化与 `keyMonitor`(当前工作区已包含该实现);建议该变更先归档或同批合并。
- **不受影响**:存储格式、设置页、剪贴板去重基线、传感器/拖放链路;`static_checks.py` 要求的既有 API 调用点不动。

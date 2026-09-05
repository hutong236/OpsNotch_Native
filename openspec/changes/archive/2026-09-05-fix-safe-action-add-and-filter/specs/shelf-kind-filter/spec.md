## MODIFIED Requirements

### Requirement: 类型筛选 chips 与归类规则

Shelf 面板展开态 SHALL 在搜索栏下方提供六个类型筛选位:全部、文件、文本、URL、应用、安全操作,默认处于"全部"。归类规则 SHALL 互斥且覆盖全部条目类型:`file` 与 `folder` 归入"文件";`text` 归入"文本";`url` 归入"URL";`application` 归入"应用";`action`(安全操作)归入"安全操作",不再并入"文件"/"URL"。任何条目在"全部"下 MUST 保持可见。

#### Scenario: 按类型筛选

- **WHEN** 列表中同时存在文件、文本、URL、应用、安全操作条目,用户点击"文件"chip
- **THEN** 列表仅显示 file/folder 条目,Pinned/Recent 分区结构保持

#### Scenario: action 条目按目标类型归类

- **WHEN** 存在一个 openURL 类 action 条目,用户选择"URL"筛选
- **THEN** 该 action 条目不可见;选择"安全操作"筛选时它可见

#### Scenario: 安全操作条目独占安全操作分类

- **WHEN** 存在一个 openPath 类 action 条目与一个 openURL 类 action 条目,用户选择"安全操作"筛选
- **THEN** 两个 action 条目均可见;选择"文件"或"URL"筛选时它们均不可见

#### Scenario: 文件夹并入文件筛选

- **WHEN** 存在 folder 类型条目,用户选择"文件"筛选
- **THEN** 该文件夹条目可见

#### Scenario: 安全操作筛选下无 action 条目时显示无匹配

- **WHEN** 列表中不存在任何 action 条目,用户点击"安全操作"chip
- **THEN** 内容区显示"没有匹配的条目"空态,而非空柜提示

### Requirement: 键盘切换与高亮回落

面板为 key 窗且处于展开态时,⌘1~⌘6 SHALL 依次切换全部 / 文件 / 文本 / URL / 应用 / 安全操作筛选位。筛选或搜索变化导致过滤结果变化后,键盘高亮 SHALL 回落到新的过滤结果首行;↑↓ 导航、Enter 复制等既有键盘流行为在筛选生效后保持不变。

#### Scenario: ⌘2 切换到文件筛选

- **WHEN** 面板展开且当前为"全部",用户按下 ⌘2
- **THEN** 筛选切换为"文件",chips 选中态同步更新

#### Scenario: ⌘6 切换到安全操作筛选

- **WHEN** 面板展开,用户按下 ⌘6
- **THEN** 筛选切换为"安全操作",chips 选中态同步更新

#### Scenario: 筛选变化后高亮回落首行

- **WHEN** 键盘高亮在第五行时用户按 ⌘3 切换到"文本"筛选
- **THEN** 高亮落在过滤后结果的第一行

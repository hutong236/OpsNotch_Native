## Purpose

让 Quick Shelf 在条目较多时可以按类型收窄列表:搜索栏下方提供类型筛选 chips(全部 / 文件 / 文本 / URL / 应用),与搜索词叠加生效,并与键盘取回流(高亮导航)打通——⌘1~⌘5 切换筛选、筛选变化后高亮回落首行、Space 预览高亮条目。

## ADDED Requirements

### Requirement: 类型筛选 chips 与归类规则

Shelf 面板展开态 SHALL 在搜索栏下方提供五个类型筛选位:全部、文件、文本、URL、应用,默认处于"全部"。归类规则 SHALL 覆盖全部条目类型:`file`、`folder` 与 openPath 类 action 归入"文件";`url` 与 openURL 类 action 归入"URL";`text` 归入"文本";`application` 归入"应用"。任何条目在"全部"下 MUST 保持可见。

#### Scenario: 按类型筛选

- **WHEN** 列表中同时存在文件、文本、URL、应用条目,用户点击"文件"chip
- **THEN** 列表仅显示 file/folder 及 openPath 类 action 条目,Pinned/Recent 分区结构保持

#### Scenario: action 条目按目标类型归类

- **WHEN** 存在一个目标为打开 URL 的 action 条目,用户选择"URL"筛选
- **THEN** 该 action 条目可见;选择"文件"筛选时它不可见

#### Scenario: 文件夹并入文件筛选

- **WHEN** 存在 folder 类型条目,用户选择"文件"筛选
- **THEN** 该文件夹条目可见

### Requirement: 筛选与搜索叠加

类型筛选 SHALL 与搜索词同时生效,取二者交集。筛选后无结果时,系统 SHALL 显示"没有匹配的条目"空态提示,与列表真正为空时的空柜提示相区分。

#### Scenario: 筛选叠加搜索词

- **WHEN** 用户选择"文本"筛选并在搜索框输入关键词
- **THEN** 列表仅显示命中关键词的 text 条目

#### Scenario: 筛选后无结果

- **WHEN** 用户选择"应用"筛选但列表中没有 application 条目
- **THEN** 内容区显示"没有匹配的条目"空态,而非空柜提示

### Requirement: 键盘切换与高亮回落

面板为 key 窗且处于展开态时,⌘1~⌘5 SHALL 依次切换全部 / 文件 / 文本 / URL / 应用筛选位。筛选或搜索变化导致过滤结果变化后,键盘高亮 SHALL 回落到新的过滤结果首行;↑↓ 导航、Enter 复制等既有键盘流行为在筛选生效后保持不变。

#### Scenario: ⌘2 切换到文件筛选

- **WHEN** 面板展开且当前为"全部",用户按下 ⌘2
- **THEN** 筛选切换为"文件",chips 选中态同步更新

#### Scenario: 筛选变化后高亮回落首行

- **WHEN** 键盘高亮在第五行时用户按 ⌘3 切换到"文本"筛选
- **THEN** 高亮落在过滤后结果的第一行

### Requirement: Space 预览高亮条目

面板为 key 窗、处于展开态且搜索框未聚焦时,Space 键 SHALL 对当前键盘高亮条目触发 Quick Look 预览(仅限可预览类型,如文件/图片);搜索框聚焦时 Space MUST 保持为普通字符输入,不触发预览。预览不收起面板、不写剪贴板。

#### Scenario: Space 预览高亮文件

- **WHEN** 键盘高亮位于一个图片文件条目上且焦点不在搜索框,用户按 Space
- **THEN** Quick Look 预览弹出,Shelf 面板保持展开

#### Scenario: 搜索框聚焦时 Space 正常输入

- **WHEN** 搜索框处于聚焦状态,用户按 Space
- **THEN** 搜索框内输入一个空格,不触发 Quick Look

### Requirement: 新增条目不受筛选隐藏

用户添加新条目(拖入、剪贴板捕获、手动添加)时,若当前类型筛选会隐藏该条目,系统 SHALL 自动把筛选重置为"全部",保证刚放入的条目对用户可见。

#### Scenario: 文本筛选下拖入文件

- **WHEN** 当前筛选为"文本",用户向 Shelf 拖入一个文件
- **THEN** 筛选自动回到"全部",新文件条目出现在 Recent 顶部

### Requirement: 筛选状态会话内生效

类型筛选 SHALL 仅在应用会话内保持(面板收起再展开不重置),应用重启后恢复为"全部"。筛选状态 MUST NOT 写入 `shelf.json` 或设置项。

#### Scenario: 重启后恢复全部

- **WHEN** 用户选择"URL"筛选后退出并重新启动应用
- **THEN** 面板筛选恢复为"全部",全部条目可见

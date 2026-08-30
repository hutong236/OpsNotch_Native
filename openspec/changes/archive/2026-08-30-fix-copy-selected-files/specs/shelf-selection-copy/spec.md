# shelf-selection-copy Delta Spec

## Purpose

定义柜内多选与选择条"复制所选"的取回行为:各条目类型复制到系统剪贴板的 payload 语义、混合选择的多 flavor 写入、应用自身复制不回灌 Recent、以及复制反馈。修复当前选中文件/图片后"复制所选"静默无效的缺陷。

## ADDED Requirements

### Requirement: 复制所选按条目类型产出 payload

选择条上执行"复制所选"时,系统 SHALL 按条目类型把选中条目写入系统剪贴板:文件/文件夹/应用条目(含图片扩展名的文件条目)SHALL 以文件 URL flavor 写入,支持一次多个文件;文字条目 SHALL 以其内容文本写入;URL 条目 SHALL 以其 URL 文本写入;action 条目 SHALL 按 `actionKind` 归类——open_path 按文件 URL、open_url 按 URL 文本。

#### Scenario: 复制单个文件条目
- **WHEN** 用户选中一个文件条目并点击"复制所选"
- **THEN** 系统剪贴板持有该条目路径对应的文件 URL,在 Finder 中 ⌘V 可粘贴出该文件

#### Scenario: 复制多个文件条目
- **WHEN** 用户多选多个文件/文件夹/应用条目并点击"复制所选"
- **THEN** 系统剪贴板同时持有全部选中条目的文件 URL,粘贴端可一次取回全部文件

#### Scenario: 复制图片文件条目
- **WHEN** 用户选中一个图片扩展名的文件条目并点击"复制所选"
- **THEN** 剪贴板持有该图片文件的文件 URL,与在 Finder 中复制该文件同语义

#### Scenario: 复制文字与 URL 条目
- **WHEN** 用户仅选中文字条目(或 URL 条目)并点击"复制所选"
- **THEN** 剪贴板持有对应文本/URL 文本,行为与既有单条复制一致

#### Scenario: 复制 action 条目
- **WHEN** 用户选中 action 条目并点击"复制所选"
- **THEN** open_path 条目按其路径产出文件 URL,open_url 条目按其 URL 产出文本,不再产出空结果

#### Scenario: 文件已不存在仍按记录路径复制
- **WHEN** 用户选中的文件条目其路径在磁盘上已不存在,并点击"复制所选"
- **THEN** 系统 SHALL 不做存在性校验,仍按记录路径写入文件 URL,与拖出行为一致;粘贴端自行处理失效引用

### Requirement: 混合选择多 flavor 写入

当同时选中文件类与文字/URL 类条目时,系统 SHALL 在同一次剪贴板写入事务中同时提供文件 URL flavor 与文本 flavor;仅选中文件类时不产出文本 flavor,仅选中文字/URL 类时不产出文件 URL flavor。

#### Scenario: 混合选择粘贴到 Finder
- **WHEN** 用户同时选中文件条目与文字条目并点击"复制所选",随后在 Finder 中 ⌘V
- **THEN** 粘贴出全部选中文件,文件不被静默丢弃

#### Scenario: 混合选择粘贴到纯文本编辑器
- **WHEN** 用户同时选中文件条目与文字条目并点击"复制所选",随后在纯文本编辑器中 ⌘V
- **THEN** 粘贴得到文字/URL 条目拼接的文本

### Requirement: 自身复制不回灌 Recent

应用执行"复制所选"写入剪贴板后,系统 SHALL 立即同步剪贴板监听的变更基线,复制内容 SHALL NOT 被剪贴板监控作为新内容重新加入 Recent。

#### Scenario: 复制所选后不产生新 Recent 条目
- **WHEN** 用户点击"复制所选"完成写入,随后剪贴板监控检查变更
- **THEN** 本次写入被识别为应用自身操作,不生成任何新条目

### Requirement: 复制反馈与无静默失败

"复制所选"对任何非空选择 SHALL 产出可写入的 payload 并给出"已复制"提示;系统 SHALL NOT 存在选中条目后点击复制却无任何写剪贴板动作、也无提示的静默无效路径。

#### Scenario: 纯文件选择出现成功提示
- **WHEN** 用户仅选中文件/图片条目并点击"复制所选"
- **THEN** 剪贴板写入文件 URL 且界面出现"已复制"提示,而非无任何反应

#### Scenario: 选择为空不可触发
- **WHEN** 用户未选中任何条目
- **THEN** 选择条(含"复制所选"入口)不展示,不存在空选择的复制触发路径

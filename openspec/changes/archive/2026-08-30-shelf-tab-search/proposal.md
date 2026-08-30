## Why

键盘取回流已实现"展开即聚焦搜索框",但用户一旦用鼠标点击过列表条目或面板内其他控件,焦点就离开了搜索框;此时想回到键盘过滤,只能重新呼出面板(收起再展开)或再点一次搜索框,键盘流出现断点。Tab 是用户在"回到搜索"上最自然的肌肉记忆,补上这一键即可让键盘取回流闭环。

## What Changes

- **Tab 回到搜索**:面板展开(key 窗)且焦点不在任何文本框时,按 Tab SHALL 把键盘焦点交回搜索框;焦点已在搜索框时,Tab 被消费(MUST NOT 把焦点移出搜索框打断键盘流)。
- 实现落在 `ShelfWindowController` 既有的本地 keyDown monitor(与 ↑↓/Enter/Esc/⌘1~5/Space 同一接管点),聚焦请求复用 `AppModel.focusRequestToken` 一次性聚焦通道,不新增状态机。
- 编辑态(editorDraft 非空)下 Tab MUST 放行为普通输入,与 Space 的放行规则一致。
- 新增 UI 文案(如有)同时加入 zh/en 两套 `L10n` 字典(预计无新增文案)。

## Capabilities

### New Capabilities

(无)

### Modified Capabilities

- `shelf-keyboard-retrieval`: 新增"Tab 回到搜索"要求——焦点丢失后可通过 Tab 恢复键盘流,焦点已在搜索框时 Tab 不移出;其余要求(展开即聚焦、↑↓/Enter/Esc、失焦隐藏等)不变。

## Impact

- `Sources/OpsNotchApp/ShelfWindowController.swift`:本地 keyDown monitor 增加 keyCode 48(Tab)分支,约 10 行;需确认 firstResponder 判定与 Space 分支的 `NSTextView` 判定一致。
- 不涉及 Core、数据格式、打包脚本;`static_checks.py` 不受影响。
- 明确不做:`/` 键唤起搜索(可后续追加)、Tab 在多控件间的完整焦点环定制、编辑态内的 Tab 缩进。

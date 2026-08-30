## Context

- 键盘取回流的按键接管集中在 `ShelfWindowController` 的 `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`(本地 monitor,面板为 key 窗且 expanded 态时生效;选择本地 monitor 而非 SwiftUI `onKeyPress` 是因为后者要求 macOS 14,项目门槛是 13)。
- 聚焦搜索框的通道已存在:`AppModel.focusRequestToken`(一次性 UUID 请求)→ `ShelfView` 的 `@FocusState`,`onReceive` 消费。
- Space 分支已确立"firstResponder 为 `NSTextView`(field editor)时放行"的判定模式;Tab 分支沿用同一判定,保证与搜索框聚焦态的判定口径一致。

## Goals / Non-Goals

**Goals:**
- Tab 在"焦点不在任何文本框"时把焦点交回搜索框;在"焦点已在搜索框"时被消费不移出。
- 实现增量最小:仅 keyDown monitor 一个新分支,复用 focusRequestToken。

**Non-Goals:**
- `/` 键唤起搜索、Tab 焦点环定制、编辑态缩进——均不在此变更。
- 不改 Core、不改数据格式、不新增文案。

## Decisions

1. **Tab 分支的行为**:keyCode 48,按当前 firstResponder 分派——非 `NSTextView` → `model.focusRequestToken = UUID()` 并消费;是 `NSTextView` 且非编辑草稿(即搜索框 field editor)→ 仍消费但不改焦点(阻止 Tab 默认的焦点环跳转把键盘流打断);`editorDraft != nil` → 整体放行(monitor 既有 guard 已覆盖)。
   备选:焦点已在搜索框时放行 Tab(交系统焦点环)——被否,会把焦点移进面板其他控件(SwiftUI 默认焦点链),键盘流断裂,与需求相反。

2. **聚焦请求走既有 `focusRequestToken` 而非直接 `makeFirstResponder`**。
   理由:`@FocusState` 由 SwiftUI 持有,AppKit 层直接操作 firstResponder 与 SwiftUI 焦点状态不同步,已验证的 token 通道无此问题。

3. **不做去抖/状态标记**:Tab 是显式用户动作,重复按只重复发聚焦请求,幂等,无需额外状态。

## Risks / Trade-offs

- [field editor 判定无法区分"搜索框 field editor"与其他文本框] → 面板内文本框仅搜索框与编辑草稿;编辑草稿被 monitor 顶部 guard 放行,其余 `NSTextView` 即搜索框,判定完备。若未来新增文本控件,需回看该分支。
- [Tab 被消费后,辅助功能(VoiceOver)用户无法用 Tab 遍历面板控件] → 面板是紧凑快捷面板而非主窗口,取舍可接受;VoiceOver 场景仍可用鼠标,不影响条目操作。

## Open Questions

(无)

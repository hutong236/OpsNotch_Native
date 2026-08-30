## Why

Shelf 的写端(拖文件/文本上 notch)必须是鼠标,但读端(找回并复用条目)目前也是全鼠标链路:悬停 notch → 面板展开 → 右键 → 菜单 → 点复制,一次取回要 4 步鼠标操作。对于高频“复制了又要用”的场景,这是整个软件效率故事的最大短板。用户需要一个不推翻 notch 空间模型的键盘取回回路:一个自己定义的全局热键呼出面板,随后全程键盘完成检索与复制。

## What Changes

- 新增**用户自定义全局呼出热键**:设置页“通用”组提供快捷键录制控件(点击进入录制态、按下组合键完成、Esc 取消、⌫ 清除),默认未设置 = 功能关闭,不替用户预置组合键。
- 热键实现为 `HotkeyService` 协议 + Carbon `RegisterEventHotKey` 薄封装(零权限、消费型热键),持久化用实现无关的 `keyCode + modifiers` 模型,未来换后端不改数据。
- 快捷键存 `ShelfSettings.hotkey: HotkeyShortcut?`(可选字段,`decodeIfPresent` 向后兼容,不 bump store 版本);校验规则(必须含 ⌘/⌃/⌥ 至少一个修饰键)落 Core 纯函数,可单元测试。
- 热键呼出语义:面板在**鼠标所在屏**展开(复用 displayTarget 空间语义);面板已展开时再按热键 = 收起(切换语义);拖放(drop)会话进行中忽略热键。
- 新增**Shelf 键盘取回流**:面板展开即搜索框获得焦点、首行(最新条目)默认高亮;↑/↓ 移动高亮,打字即时过滤(复用 `ShelfLogic.matches`);Enter = 复制当前高亮条目到剪贴板 + toast + 短延迟自动隐藏;Esc = 直接隐藏不复制。
- 面板为接收键盘需成为 key 窗:补“面板失焦/应用切走即联动隐藏”的分支,避免 accessory 应用留下孤岛浮窗。
- 复制条目(键盘 Enter 或既有右键复制)时刷新该条目 `updatedAt`,使其按现有排序规则上浮至 Recent 分区顶部(穷人版最近使用)。
- 同步修订文档:AGENTS.md 的 “No custom global hotkeys” 规则改写为“用户可选自定义热键、Carbon 实现、默认关闭、不引入快捷键插件”;VERIFY_ON_MAC.md 验收清单补热键与键盘流条目。
- 新增 UI 文案同时加入 zh/en 两套 `L10n` 字典;代码命名避开连字符形式的全局快捷键插件名(static_checks 敏感词)。

## Capabilities

### New Capabilities

- `hotkey-summon`: 用户自定义全局呼出热键 —— 录制交互、校验规则、持久化、注册/注销生命周期、呼出与切换隐藏语义、拖放会话期间的忽略规则、注册冲突的错误反馈。
- `shelf-keyboard-retrieval`: Shelf 面板展开后的键盘取回流 —— 展开即聚焦搜索、默认高亮与 ↑↓ 导航、过滤联动、Enter 复制即走(复制+toast+自动隐藏)、Esc 隐藏、失焦联动隐藏、复制刷新 `updatedAt` 使条目上浮。

### Modified Capabilities

(无 —— 既有 `shelf-items` 置顶/排序要求不变:排序键本就是 `updatedAt`,本变更只是让复制动作也写入该字段,属于新能力 `shelf-keyboard-retrieval` 的行为要求。)

## Impact

- `Sources/OpsNotchCore/Models.swift`:新增 `HotkeyShortcut` 值类型;`ShelfSettings` 加可选 `hotkey` 字段(`decodeIfPresent`,旧 `shelf.json` 兼容)。
- `Sources/OpsNotchCore/HotkeyValidation.swift`(新):修饰键约束等纯函数校验,XCTest 覆盖。
- `Sources/OpsNotchApp/HotkeyService.swift`(新):协议 + Carbon `RegisterEventHotKey` 薄封装(约百行,无第三方依赖),注册失败(组合键被占用)上报错误。
- `Sources/OpsNotchApp/SettingsWindowController.swift`:通用组新增快捷键录制行(NSViewRepresentable 录制控件),冲突红字提示。
- `Sources/OpsNotchApp/ShelfView.swift`:`@FocusState` 搜索聚焦、高亮选中态(与多选删除的蓝底区分)、↑↓/Enter/Esc 键处理、Enter 复制链路。
- `Sources/OpsNotchApp/ShelfWindowController.swift`:面板 key 窗化(`.nonactivatingPanel` 风格位)+ 失焦联动隐藏;热键呼出/切换入口接线。
- `Sources/OpsNotchApp/AppModel.swift` / `ShelfStoreService.swift`:复制动作刷新 `updatedAt` 并落盘。
- `Sources/OpsNotchApp/Localization.swift`:新增 zh/en 文案(设置行、录制提示、冲突提示等)。
- `Tests/OpsNotchCoreTests/`:快捷键校验、`updatedAt` 刷新与排序上浮、settings 向后兼容解码。
- 文档:AGENTS.md(规则修订)、VERIFY_ON_MAC.md(验收清单)。
- 与进行中变更 `add-item-floating-preview` 无文件面冲突(仅都读 `ShelfLogic.matches`,且均不改 Core 模型既有字段语义)。
- 明确不做:URL 自动识别(另立变更)、自定义面板内其他键位、多热键。

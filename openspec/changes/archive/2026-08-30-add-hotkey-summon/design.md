## Context

Shelf 面板是 `ShelfWindowController` 管理的 borderless `NSPanel`(styleMask `[.borderless, .fullSizeContentView]`,level `.floating`,`hidesOnDeactivate = false`),内容为 SwiftUI `ShelfView` 经 NSHostingView 承载;面板内**无任何键盘快捷键**,搜索框(`ShelfView.swift`)存在但需鼠标点击聚焦。复制链路现成:`ShelfView` 右键“复制”调 `ClipboardManager.copyFromApp`(含防回灌基线更新)。排序现成:`ShelfLogic.ordered` 已按 `updatedAt` 降序,只是复制动作不写该字段。本项目为 SPM 构建、macOS 13 起步、accessory 应用(无 Dock)、zh/en 运行时 L10n、零第三方依赖;AGENTS.md 原规则 “No custom global hotkeys” 需随本变更修订。动机见 proposal.md。

## Goals / Non-Goals

**Goals:**

- 全局呼出热键零权限、消费型(按键不穿透前台 App),实现被隔离在协议之后,后端可整体替换。
- 快捷键模型与校验在 Core(UI-free、可 XCTest),注册/监听在 App 层(AppKit 管系统交互)。
- 键盘取回流复用既有搜索/复制/排序链路,新增面最小:聚焦、高亮、键处理、自动隐藏。
- 面板 key 窗化后不破坏 accessory 模型:不激活 App、不驻留孤岛浮窗。
- 旧 `shelf.json` 零迁移。

**Non-Goals:**

- 不做自定义面板内其他键位(Enter/Esc/↑↓ 语义固定),不做多热键,不做热键与命令式动作的自由绑定。
- 不做 URL 自动识别(另立变更)。
- 不引入第三方快捷键库(KeyboardShortcuts/MASShortcut 等)。
- 不 bump `ShelfStore.currentVersion`;不改既有字段语义。
- 不支持无修饰键的单键呼出。

## Decisions

1. **Carbon `RegisterEventHotKey` 作为热键后端,否决 NSEvent 全局监听。**
   - NSEvent `addGlobalMonitorForEvents(.keyDown)` 被否的两条理由:① macOS 10.15+ 监听键盘事件需“输入监听”权限,不授权则**静默收不到事件**,权限摩擦与 Apple 收紧隐私权限的趋势(如 macOS 15 录屏周期重授权)相悖;② 全局 monitor 是**被动观察、不能消费事件**——组合键会穿透前台 App(如 ⌥O 呼出面板的同时在用户文档敲出 “ø”),对呼出场景是硬伤。
   - Carbon 热键注册即独占消费、零权限、沙盒可用、macOS 13–15 实证稳定(KeyboardShortcuts/MASShortcut 等主流库同路径),且天然只支持“修饰键+普通键”,正好约束危险面。
   - 代价:C 接口,约 100 行薄封装(`CarbonHotkeyService`),无第三方依赖。

2. **`HotkeyService` 协议隔离实现,持久化模型实现无关。**
   - App 层定义 `HotkeyService`(`start(shortcut)` / `stop()` / `onFire` 回调),Carbon 实现为首个后端。持久化的 `HotkeyShortcut { keyCode: UInt32, carbonModifiers: UInt32 }` 中 keyCode 是各后端共用的虚拟键码空间,modifiers 映射是平凡函数——未来若 Apple 废弃 Carbon 热键,换 NSEvent 后端只动一个文件,**用户已录快捷键无需重录**。

3. **快捷键模型与校验进 Core。**
   - `HotkeyShortcut`(Codable/Equatable/Sendable)入 `Models.swift`;`ShelfSettings` 加 `hotkey: HotkeyShortcut? = nil`,`init(from:)` 用 `decodeIfPresent`——旧 JSON 读出 nil(功能关闭),旧版 App 读新 JSON 忽略未知字段,双向兼容,不 bump store 版本。
   - 校验为 Core 纯函数(如 `HotkeyValidation.isAcceptable(keyCode:modifiers:)`):必须含 ⌘/⌃/⌥ 至少一个 + 一个普通键;拒绝仅 ⇧ 组合、纯修饰键、单普通键。XCTest 直接覆盖。

4. **录制控件:NSViewRepresentable 包一层 key-capture NSView。**
   - 标准录制模式:控件成为 first responder 后捕获 `keyDown`——合法组合→提交;Esc→取消;⌫→清除;其余键忽略。显示态把 keyCode+modifiers 渲染为 `⌃⌥O` 式字形(无修饰键时键名字符)。
   - 注册冲突(Carbon 返回 `eventHotKeyExistsErr`)时录制区回滚显示原值并红字提示,热键行为不变(满足 spec 的冲突反馈要求)。

5. **面板 key 窗化:styleMask 加 `.nonactivatingPanel`,失焦联动隐藏。**
   - `.nonactivatingPanel` 让面板可成 key 窗接收键盘而**不激活 accessory App**、不抢用户前台应用。与进行中变更 `add-item-floating-preview` 的 FloatingPreviewController 同款方案,本项目内已有先例。
   - 隐藏联动挂 `NSWindow.didResignKeyNotification` + 既有 `scheduleHide`:面板失 key 且非右键菜单追踪中(`NSApp.keyWindow?.level == .popUpMenu` 判定现成)→ 立即隐藏,杜绝孤岛浮窗。

6. **键盘取回流:高亮是独立轻状态,不复用多选集合。**
   - `model.selection`(Set<UUID>)服务多选删除(蓝底样式),键盘高亮是单一“当前行”语义(浅色描边/底),两者视觉与语义都不同,故 AppModel 加独立 `highlightedID: UUID?`,展开/过滤变化时重置为首行。
   - 键处理在 SwiftUI 侧:搜索 TextField 加 `@FocusState`,面板展开(expanded 态)后置 focus;↑↓/Enter/Esc 用 `.onKeyPress` 挂在列表容器上(TextField 聚焦时 ↑↓/Enter/Esc 默认不被 TextField 消费,可安全接管);编辑草稿 sheet 打开期间不接管 Enter(sheet 已有 `.keyboardShortcut(.defaultAction)`,状态由 `model.editorDraft != nil` 守卫)。
   - Enter 链路:`clipboard.copyFromApp(item.content)` → `model.touchItem(item.id)`(刷新 updatedAt 落盘)→ toast → `scheduleHide(delay: ~0.6)`。复制沿用既有安全通道,纯剪贴板写入,无 SafeAction 新面。

7. **呼出落屏:固定取鼠标所在屏,与 displayTarget 设置解耦。**
   - 热键呼出是“注意力在哪,货架在哪”的远程召唤,直接复用 `showExpanded(on:)` 传鼠标所在屏(`NSScreen.screens` + `NSEvent.mouseLocation` 命中判定);displayTarget 设置项继续只管 notch 传感器分布,语义不混淆。

8. **drop 态守卫:热键与聚焦都让位于拖放。**
   - 热键回调先查 Shelf 当前 presentation,drop 态直接忽略;展开聚焦仅在 expanded/peek 等静态展示态执行。拖放会话的完整性优先于一切键盘交互。

## Risks / Trade-offs

- [Carbon API 名义上是 legacy,存在远期被 Apple 废弃的可能] → 决策 2 的协议缝:换后端成本约一个文件;持久化模型后端无关;design 记录否决 NSEvent 的两条理由防止无依据翻案。
- [`.nonactivatingPanel` + accessory 组合下 key 窗行为(选中、复制键)在不同 macOS 版本可能有细微差异] → CI/单测无法覆盖,按 VERIFY_ON_MAC.md 手测;同款方案已用于进行中的悬浮预览变更,风险共摊。
- [用户录制的组合键与系统/前台应用快捷键语义冲突但 Carbon 注册成功(如 ⌘Space 被 Spotlight 抢占导致不触发)] → 冲突提示只能覆盖注册失败场景;抢占类冲突在设置页文案中提示“若不生效请换一组”,不做系统级冲突枚举(不可可靠实现)。
- [面板 key 窗化后,`hidesOnDeactivate = false` 与失焦隐藏可能产生竞态(右键菜单打开时误判失焦)] → 复用现有 `popUpMenu` 判定豁免;新增分支进 VERIFY_ON_MAC.md 手测清单。
- [`static_checks.py` 敏感词] → 命名用 `HotkeyService`/`hotkey` 等无连字符形式;注释不写受禁插件名。
- [`swift run` 下全局热键与 key 窗行为可能与 .app 不完全一致] → 与登录项/传感器同一限制,验收以 `./script/build_and_run.sh` 打包为准。

## Migration Plan

无数据迁移:`hotkey` 为可选字段,旧 `shelf.json` 读出 nil;回滚即删除新增文件与接线,旧版应用读含 `hotkey` 字段的 JSON 会忽略未知字段,不报错。文档(AGENTS.md 规则、VERIFY_ON_MAC.md 清单)与代码同变更落地,避免规则与实现脱节。

## Open Questions

- ↑↓ 导航到列表边界时停止还是循环:spec 允许二选一,实现时取“停止”(更不易误操作),如手测反馈不佳再调。

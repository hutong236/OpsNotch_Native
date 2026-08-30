## 1. Core:快捷键模型与校验

- [x] 1.1 在 `Models.swift` 新增 `HotkeyShortcut`(Codable/Equatable/Sendable,字段 `keyCode: UInt32`、`carbonModifiers: UInt32`);`ShelfSettings` 加 `hotkey: HotkeyShortcut?` 默认 nil,`init(from:)` 用 `decodeIfPresent` 解码;验证 `swift test` 通过且新增解码测试:不含 hotkey 字段的旧 JSON 解码成功且 hotkey 为 nil,含字段的 JSON 往返编解码一致
- [x] 1.2 新增 `Sources/OpsNotchCore/HotkeyValidation.swift` 纯函数校验(必须含 ⌘/⌃/⌥ 至少一个修饰键 + 一个普通键;拒绝仅 ⇧、纯修饰键、单普通键);验证 XCTest 覆盖接受/拒绝各分支,`swift test` 全绿
- [x] 1.3 AppModel 新增复制后刷新条目 `updatedAt` 并落盘的接口(如 `touchItem(id:)`),Core 层逻辑保持 UI-free;验证 XCTest:复制刷新后该条目按 `ShelfLogic.ordered` 升至所在分区顶部,置顶条目不分区迁移

## 2. App:HotkeyService(Carbon 后端)

- [x] 2.1 新增 `Sources/OpsNotchApp/HotkeyService.swift`:定义 `HotkeyService` 协议(start/stop/onFire)+ `CarbonHotkeyService` 实现(`RegisterEventHotKey`/`UnregisterEventHotKey` + Carbon 事件 handler 薄封装);注册失败(组合键被占用)以错误类型上报;验证 `swift build` 通过,无第三方依赖引入
- [x] 2.2 应用启动/设置变更时按 `settings.hotkey` 注册或注销热键;热键回调先查 Shelf presentation,drop 态忽略,expanded 态切换隐藏,否则以鼠标所在屏(`NSScreen.screens` + `NSEvent.mouseLocation`)调 `showExpanded(on:)`;验证 `./script/build_and_run.sh` 打包后真机手测:录制 ⌃⌥O → 其他应用前台按下呼出/再按收起/拖放悬停时按下无效果

## 3. App:面板 key 窗化与失焦隐藏

- [x] 3.1 `ShelfWindowController` 面板 styleMask 增加 `.nonactivatingPanel`,展开态 show 后使面板成为 key 窗(不激活 App);验证真机:面板展开后前台应用保持 active,面板可接收键盘
- [x] 3.2 挂 `NSWindow.didResignKeyNotification`:面板失 key 且非右键菜单追踪(复用 `popUpMenu` level 判定)时立即隐藏;drop 态不聚焦、不接管;验证真机:面板展开后点击其他应用窗口,面板自动隐藏;右键菜单打开期间切菜单项不误隐藏

## 4. App:键盘取回流(ShelfView + AppModel)

- [x] 4.1 AppModel 加 `highlightedID: UUID?`,展开/搜索词变化/列表变化时重置为过滤后首行;ShelfView 搜索框加 `@FocusState`,expanded 态展开后自动聚焦;验证真机:热键呼出后直接打字即过滤,首行高亮
- [x] 4.2 列表容器接管 ↑↓(移动高亮,边界停止)、Enter(复制高亮条目:`copyFromApp` + `touchItem` + toast + `scheduleHide(~0.6s)`)、Esc(直接隐藏);`model.editorDraft != nil` 时让出 Enter;高亮样式与多选蓝底区分;验证真机:↑↓ 移动、Enter 复制后面板自动隐藏且可 Cmd+V 粘贴、Esc 无复制隐藏、编辑弹窗中 Enter 仍走保存
- [x] 4.3 既有右键“复制”链路同样接 `touchItem`;验证真机:右键复制中部条目后重开面板,该条目在 Recent 顶部;且两次复制不产生剪贴板回灌重复条目

## 5. App:设置页录制控件与文案

- [x] 5.1 `SettingsWindowController` 通用组加“呼出快捷键”行:NSViewRepresentable 录制控件(点击录制、Esc 取消、⌫ 清除、非法组合提示、注册冲突红字回滚),绑定 `settings.hotkey`;验证真机:录制/取消/清除/冲突(占用 ⌘Space 类组合)四种路径表现符合 spec
- [x] 5.2 `Localization.swift` 新增 zh/en 文案(录制区提示、校验提示、冲突提示等);验证设置页双语言切换显示正常

## 6. 文档与门禁

- [x] 6.1 AGENTS.md “No custom global hotkeys” 改写为“用户可选自定义热键:Carbon 实现、默认关闭、不引入快捷键插件”;VERIFY_ON_MAC.md 验收清单补:热键呼出/切换/拖放忽略、展开即聚焦、↑↓/Enter/Esc 键盘流、失焦隐藏、复制上浮;验证 diff 中规则描述与实现一致
- [x] 6.2 全量门禁:`swift test`、`swift build`、`python3 scripts/static_checks.py` 全过;命名与注释不含受禁连字符插件名;验证三条命令本地依次执行退出码为 0

## Context

- 既有 summon 语义集中在 `ShelfWindowController.toggleSummon()`:未展开 → 鼠标所在屏展开(expanded,搜索框自动聚焦),已展开 → 收起;`AppDelegate` 已把热键 `onFire` 接到它。热键(默认关闭)、悬停 notch 是仅有的两个入口。
- 面板是 `.nonactivatingPanel` 风格的 `NSPanel`,App 为 accessory 激活策略,呼出不抢前台焦点。
- 构建链路是纯 SwiftPM(`swift build` + `scripts/build_app.sh` 拼包),没有 Xcode 构建系统;`appintentsmetadataprocessor`(App Shortcuts 元数据提取)是 Xcode 构建期工具,SwiftPM 链路默认不执行。
- 冷启动 vs reopen:LaunchServices 只对"已在运行"的应用投递 reopen(`rapp`)事件;首次启动不投递。`NSApplicationDelegate.applicationShouldHandleReopen` 因此天然只在运行态被调用,与"冷启动不自动展开"的要求天然对齐。

## Goals / Non-Goals

**Goals:**
- 聚焦输应用名回车 → 唤起/收起 Shelf,零权限、零设置项。
- 三入口(悬停、热键、打开事件)行为完全一致,复用 `toggleSummon()`。
- App Intents 短语增强在真机 .app 产物上验证,可行则交付,不可行干净回退。

**Non-Goals:**
- CoreSpotlight 条目索引(聚焦搜 Shelf 条目内容)——另立变更。
- 定制聚焦 UI 内的按键(系统限制,不可行)。
- 改变冷启动/登录项行为。

## Decisions

1. **主机制用 `applicationShouldHandleReopen` 而非 App Intents**。
   理由:聚焦默认就收录所有应用,输应用名回车即产生打开事件;该路径是纯 AppKit 回调,零构建工具依赖、零元数据风险,且 reopen 仅在运行态触发,天然满足冷启动静默要求。
   备选:仅做 App Intents —— 被否,SwiftPM 下元数据提取不可控,可能整条路不通。
   备选:自定义 URL scheme(`opsnotch://summon`)—— 被否,聚焦不会展示 scheme,仍需另一入口配合,增量无意义。

2. **重入去抖放在 AppDelegate 接线层,`toggleSummon()` 保持纯净**。
   系统/激活流程可能连续投递 reopen(如应用激活附带事件)。在 AppDelegate 内加时间窗去抖(同一来源 300ms 内的重复投递折叠为一次),不修改 `toggleSummon()` 本身——热键与悬停路径不受去抖影响,用户快速双击热键的切换语义保持原样。
   备选:在 `toggleSummon()` 内去抖 —— 被否,会改变既有热键语义。

3. **App Intents 增强作为独立可失败任务**。
   `SummonIntent` 定义在 App target(`Sources/OpsNotchApp/SummonIntent.swift`),`perform()` 通过 `DistributedNotificationCenter`/静态共享引用调用 AppDelegate 的 summon 入口,不 import Core。若在 `scripts/build_app.sh` 产物上实测 Spotlight 不收录短语(手动运行 `appintentsmetadataprocessor` 也失败),则删除该文件并回退主机制,结论写入本文档"Risks"。规范层面允许此回退,避免留半成品。

4. **拖放忽略复用既有状态机**:打开事件入口与热键一致,在 `toggleSummon()` 已有的 drop 态守卫下自然生效,不新增判定分支。

5. **不动 Core 与数据格式**:本变更全部落在 `OpsNotchApp` 与打包脚本,`shelf.json` 无新字段,`static_checks.py` 无需更新(命名避开敏感词)。

## Risks / Trade-offs

- [reopen 事件可能在非用户意图场景触发(如脚本 `open`、自动化工具)] → 可接受:与"Finder 双击"同级,仍是用户侧打开行为,切换语义幂等。
- [accessory 应用被聚焦回车后系统激活,焦点短暂离开前台应用] → 面板为 nonactivating panel,accessory 策略下无可视激活;验收项明确覆盖"前台应用不被替换"。
- [App Intents 元数据在 SwiftPM 链路不可提取] → 主机制不依赖它;增强任务显式设计为可失败回退。
- [聚焦"打开"语义对未运行的应用是启动而非打开事件] → 规范已覆盖:冷启动不展开,二次回车才唤起;在 VERIFY_ON_MAC 记录该双段行为,避免用户误判为 bug。

## Open Questions

(无——App Intents 可行性通过实施期真机验证回答,不阻塞任务拆分。)

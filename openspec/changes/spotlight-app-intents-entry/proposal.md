## Why

OpsNotch 的呼出入口目前只有两个:鼠标悬停 notch、用户自定义全局热键(默认关闭)。不设热键、也不方便把鼠标挪到屏幕顶部的用户缺少一个零配置的呼出方式;而 macOS 聚焦(Spotlight)是所有用户默认就会用的入口——输 "Ops Notch" 回车即可唤起,不需要任何权限、不需要设置项。

## What Changes

- **聚焦唤起 Shelf**:用户在 Spotlight 输入应用名并回车,App 被系统"打开"时,Shelf 面板在鼠标所在屏展开(与热键 summon 同一语义与空间规则),再次走同一入口 = 收起(切换语义)。
- 实现机制分两层:
  - **主机制(零新依赖、零构建工具风险)**:App 层处理系统的 launch/reopen Apple Event——App 已在运行时,聚焦回车 / Finder 双击 / `open` 命令都会触发 reopen 回调,在其中调用既有 `ShelfWindowController.toggleSummon()`;冷启动(dock 外首启,含登录项自启)不自动展开面板,保持静默,避免开机时面板弹出的意外行为。
  - **增强机制(可选交付,带验证开关)**:新增 `AppIntents` 的 `AppShortcutsProvider` 动作("打开 Ops Notch 清单"),让聚焦能以短语直接执行唤起。**SwiftPM 构建链路不含 `appintentsmetadataprocessor`,App Shortcuts 元数据可能不被系统收录**——实现时在 `./scripts/build_app.sh` 产物上实测;若元数据提取不可行,则砍掉该增强、保留主机制,并在 design.md 记录结论(允许此变更范围内失败,不阻塞主机制)。
- 唤起语义复用既有键盘取回流:面板展开即搜索框聚焦,可直接打字过滤(本变更不新增键位,Tab 交互另立变更 `shelf-tab-search`)。
- 新增 UI 文案(如有,如 App Shortcuts 短语)同时加入 zh/en 两套 `L10n` 字典。

## Capabilities

### New Capabilities

- `spotlight-summon`: 通过系统"打开应用"事件(Apple Event reopen)与 App Intents 快捷短语唤起/收起 Shelf 的行为规范——reopen 触发切换语义、鼠标所在屏展开、拖放会话期间忽略、冷启动不自动展开、登录项自启不触发。

### Modified Capabilities

- `hotkey-summon`: 呼出/收起的切换语义、鼠标所在屏、拖放会话忽略等要求原本仅绑定在热键入口上;本变更将"呼出"抽象为多入口共享的 summon 语义(热键、reopen、App Intents 三入口等价),该 capability 的需求措辞从"热键呼出"扩展为"任一入口呼出,行为一致"。(实现细节收敛,不改变热键本身任何行为。)

## Impact

- `Sources/OpsNotchApp/AppDelegate.swift`:实现 `applicationShouldHandleReopen`(或 `NSApplication.delegate` 的 reopen 回调)→ `shelf.toggleSummon()`;若走 App Intents,新增 `Sources/OpsNotchApp/SummonIntent.swift`。
- `Sources/OpsNotchApp/ShelfWindowController.swift`:`toggleSummon()` 语义不变,仅确认多入口并发调用安全(重入幂等)。
- `scripts/build_app.sh`:若 App Intents 元数据需手动提取,在此追加 `appintentsmetadataprocessor` 调用(仅当验证可行)。
- 文档:`VERIFY_ON_MAC.md` 补聚焦唤起验收项;`ARCHITECTURE.md` 如提及入口清单则同步。
- 不涉及 Core(`OpsNotchCore`)与 `shelf.json` 格式;`static_checks.py` 敏感词与必含调用点不受影响(AppIntents 命名避开 `global-shortcut` 等敏感串)。
- 明确不做:CoreSpotlight 条目索引(聚焦中搜索 Shelf 条目内容,另立变更);聚焦 UI 内的按键定制(系统限制,不可行)。

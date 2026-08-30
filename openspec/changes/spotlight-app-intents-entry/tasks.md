## 1. 打开事件入口(主机制)

- [x] 1.1 在 `AppDelegate` 实现 reopen 接线:`applicationShouldHandleReopen(_:hasVisibleWindows:)` → 带时间窗去抖(300ms)后调用 `shelf.toggleSummon()`;确认冷启动路径(`didFinishLaunching`、登录项自启)不触发 summon。验证:`swift build` 通过;`swift test` 无回归。
- [x] 1.2 确认 `toggleSummon()` 在 drop 态守卫下对打开事件入口自然生效,不新增状态分支;确认三入口(悬停/热键/打开事件)共用同一 `toggleSummon()` 调用点。验证:代码审阅 + `python3 scripts/static_checks.py` 通过。
- [x] 1.3 单元测试(如去抖逻辑可下沉为 Core 纯函数则测 Core;否则以实现说明替代):去抖窗口内重复投递折叠为一次。验证:`swift test` 通过。

## 2. App Intents 增强(可失败回退)

- [x] 2.1 新增 `Sources/OpsNotchApp/SummonIntent.swift`:AppIntent 动作 + AppShortcutsProvider 短语(zh/en),`perform()` 调用 AppDelegate summon 入口,不 import Core,命名避开 static_checks 敏感词。验证:`swift build` 通过。
- [ ] 2.2 打包验证元数据:用 `./scripts/build_app.sh` 出 .app,必要时在脚本中手动接入 `appintentsmetadataprocessor`;在产物上实测聚焦是否收录短语。验证:真机记录结论(收录/不收录)。
- [ ] 2.3 依据 2.2 结论收敛:收录则保留并补验收文档;不收录则删除 `SummonIntent.swift` 及脚本改动,回退主机制。验证:`swift build`、`swift test`、`scripts/static_checks.py` 全部通过,无残留死代码。

## 3. 文档与验收

- [x] 3.1 `VERIFY_ON_MAC.md` 补验收项:聚焦回车唤起/再回车收起、鼠标所在屏、冷启动静默、登录项自启不弹面板、拖放中打开事件无效、前台应用不被替换。验证:文档更新完成。
- [x] 3.2 若 `ARCHITECTURE.md` 入口清单/相关章节受影响则同步修订。验证:文档一致。
- [ ] 3.3 真机走一遍 VERIFY_ON_MAC 新增项(按记忆:GUI 验收交用户执行,提供清单)。验证:用户确认或记录待验收。

# Tasks

- [x] 在 `AppDelegate` 增加统一的终止前菜单栏恢复流程。
- [x] 退出前展开普通隐藏区与持续隐藏区，并关闭隐藏图标代理面板。
- [x] 使用 `.terminateLater` 将真正退出延后到下一轮主线程 runloop。
- [x] 恢复终止前的 `menuBarLastState`，不改变下次启动偏好。
- [x] 在 `applicationWillTerminate` 增加幂等兜底。
- [ ] CI：`swift test`、`swift build`、`scripts/static_checks.py`。
- [ ] macOS 手工验收：collapsed、持续隐藏区、隐藏图标面板打开时分别执行“退出”。

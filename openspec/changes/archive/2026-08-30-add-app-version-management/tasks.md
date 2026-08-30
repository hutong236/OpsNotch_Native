## 1. 版本读取服务

- [x] 1.1 新增 `Sources/OpsNotchApp/AppVersionService.swift`：读取 `Bundle.main` 的 `CFBundleShortVersionString`，缺失或为空时返回 `"0.0.0-dev"`；`swift build` 通过，`swift test` 全绿（Core 不受影响）

## 2. 构建脚本注入

- [x] 2.1 修改 `scripts/build_app.sh`：拷贝 `Info.plist` 后，若设置 `APP_VERSION` 且匹配 `^[0-9]+\.[0-9]+\.[0-9]+$`，用 PlistBuddy 写入产物 `CFBundleShortVersionString` 并派生 `CFBundleVersion`（去点号），非法值报错退出；验证 `APP_VERSION=2.1.0 ./scripts/build_app.sh` 后产物 `Info.plist` 为 `2.1.0`/`210`，不设变量时保持根 `Info.plist` 默认值
- [x] 2.2 修改 `script/build_and_run.sh` 加入与 2.1 相同的注入逻辑；验证 `--verify` 变体及默认路径下打包产物版本正确

## 3. 界面展示

- [x] 3.1 修改 `StatusBarController.rebuildMenu()`：在设置项之前插入禁用的版本信息项（`Ops Notch v<版本>`，无 action）；构建通过后手动打开菜单确认版本项可见且点击无响应
- [x] 3.2 修改 `SettingsView`：底部新增小号灰色 about 行 `Ops Notch v<版本>`；构建通过后打开设置窗口确认显示，且与状态栏菜单版本一致
- [x] 3.3 确认 zh/en 语言切换后状态栏菜单与设置窗口的版本展示均正常刷新（`rebuildMenu()` 既有机制即可，若设置窗口需刷新则补齐）；zh/en 两种语言下分别验证

## 4. 集成验收

- [x] 4.1 运行 `python3 scripts/static_checks.py` 通过；`swift build`、`swift test` 全绿
- [x] 4.2 按 `VERIFY_ON_MAC.md` 手动验收：以 `./script/build_and_run.sh` 打包启动，核对状态栏菜单与设置窗口展示的版本号与产物 `Info.plist` 的 `CFBundleShortVersionString` 一致

## Why

应用的版本号目前只写在根目录 `Info.plist` 的 `CFBundleShortVersionString`/`CFBundleVersion` 中，仅作为构建产物元数据存在：没有单一可信来源，也没有任何界面展示。用户无法直观确认当前运行的是哪个版本，发版时也需要手动同步多处版本号，容易遗漏或不一致。

**范围假设**：本变更中的"版本管理"指**应用自身的版本号管理**（版本的单一来源、构建注入、界面展示），不涉及货架条目（ShelfItem）的历史版本功能。如需条目级版本历史，应另立变更。

## What Changes

- 新增统一的应用版本来源：以 `Info.plist` 的 `CFBundleShortVersionString` 为唯一权威版本号，代码侧通过 Bundle 读取（`AppVersionService`），不再在 Swift 代码中硬编码版本字符串。
- 构建脚本（`scripts/build_app.sh`、`script/build_and_run.sh`）支持通过环境变量/参数（如 `APP_VERSION`）注入版本号到 `Info.plist`，默认值取自根 `Info.plist`，保证 CI 打包与本地打包行为一致。
- 界面展示版本号：
  - 状态栏菜单（`StatusBarController`）显示版本项（不可点击的信息行，如 "Ops Notch v2.0.1"）。
  - 设置窗口（`SettingsWindowController`）底部显示应用名称 + 版本号。
- 新增字符串进入 `Localization.swift` 的 zh/en 双语字典。

## Capabilities

### New Capabilities

- `app-version`: 应用版本号的管理（单一来源、构建注入）与界面展示（状态栏菜单、设置窗口）要求。

### Modified Capabilities

（无 — 现有 `shelf-items` 与 `git-repo-config` 规格不受影响。）

## Impact

- `Sources/OpsNotchApp/`：新增 `AppVersionService.swift`；修改 `StatusBarController.swift`、`SettingsWindowController.swift`、`Localization.swift`。
- `Info.plist`：作为版本权威来源，可能更新版本号占位逻辑。
- `scripts/build_app.sh`、`script/build_and_run.sh`：注入版本号（`PlistBuddy`/`plutil`）。
- `.github/workflows/macos-ci.yml`：打包 workflow 若需固定/提升版本号，通过 `APP_VERSION` 传入（可选）。
- 无数据格式变化（`shelf.json` 的 `ShelfStore.version` 是存储格式版本，与本变更无关，保持不动）。

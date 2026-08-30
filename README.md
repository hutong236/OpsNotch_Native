# Ops Notch Native

Ops Notch 是一款 macOS 刘海(Notch)/ Shelf 工具:把文件、文件夹、URL 或选中文字拖到屏幕顶部的透明 Sensor,即可收入 Shelf;复制文字后触碰刘海,内容自动进入 Recent。应用平时完全隐藏,无 Dock 图标,通过菜单栏操作。

本项目由 Tauri / React / Vite 版本原生重写而来:

- **Swift**:业务逻辑与数据模型(`OpsNotchCore`)
- **AppKit**:刘海 Sensor、窗口、多显示器、拖放、剪贴板、状态栏、Quick Look
- **SwiftUI**:Shelf 内容、Pinned / Recent、搜索、编辑、设置
- **Swift Package Manager**:无 Node.js、无 npm、无 Vite、无 localhost 服务

版本与变更记录见 [CHANGELOG_V2.0.1.md](CHANGELOG_V2.0.1.md)。

## 核心交互

```text
文件 / 文件夹 / URL / 选中文字
              │
              ▼
        拖到屏幕顶部 Sensor
              │
              ▼
          松开放入 Shelf

⌘C 复制文字
      │
      ▼
触碰任意显示器顶部 Sensor
      │
      ▼
Clipboard Catch → Recent
```

平时主 Shelf 窗口完全隐藏。每块显示器顶部有一个透明 AppKit Sensor;在哪块屏幕触发,Shelf 就出现在哪块屏幕。

## 功能概览

- **拖放捕获**:文件 / 文件夹 / 多文件 / URL / 选中文字;来源 App 发出系统 Drag Pasteboard 即可接收(含三指拖移)
- **Clipboard Catch**:复制文字后触碰 Sensor 自动进入 Recent,按 `changeCount` 去重,不重复导入
- **条目操作**:Text 点击复制、File / Folder 打开、URL 浏览器打开、Application 启动;Quick Look、Reveal in Finder;原生拖出,多选后可发起多项目 Drag Session
- **整理**:Pinned / Recent、搜索、Recent TTL 自动清理、Reference / Copy-in 两种存储模式
- **多显示器**:每块屏幕独立 Sensor;插拔 / 排列 / 分辨率变化事件驱动自动重建,无轮询
- **系统集成**:登录启动(`SMAppService.mainApp`)、菜单栏(`NSStatusItem` + SF Symbol)、无 Dock 图标(Accessory policy)、无自定义全局快捷键、中英文运行时切换
- **安全**:所有条目动作经 `SafeActionValidator.validate`,仅允许本地绝对路径与 http/https,无任何 shell / 命令执行能力

完整功能与 V1.x 对照见 [FEATURE_MATRIX.md](FEATURE_MATRIX.md)。

## 环境要求

- macOS 13+(`Package.swift` 平台声明与 `Info.plist` 的 `LSMinimumSystemVersion` 一致)
- Swift 5.9+(建议 Xcode 15+)
- 开发与打包脚本仅支持 macOS

## 开发运行

### Xcode

```bash
xed .
```

Xcode 直接识别 `Package.swift`,选择 `OpsNotch` scheme 后 Run。

### 命令行

```bash
swift test          # Core 单元测试
swift build         # Debug 构建
```

### 开发入口:script/build_and_run.sh(推荐)

```bash
./script/build_and_run.sh            # 构建 + 打包到 dist/ + 启动
./script/build_and_run.sh --debug    # lldb 调试
./script/build_and_run.sh --logs     # 启动并跟随 os_log 日志
./script/build_and_run.sh --telemetry  # 与 --logs 相同的日志跟随
./script/build_and_run.sh --verify   # 启动并校验进程存活(PASS)
```

脚本会先 `swift build`,打包为 `dist/Ops Notch.app`,ad-hoc 签名后启动。

### script/ 与 scripts/ 的分工

| 目录 | 脚本 | 用途 |
|---|---|---|
| `script/`(单数) | `build_and_run.sh` | 日常开发入口:构建、打包到 `dist/`、启动、调试变体 |
| `scripts/`(复数) | `build_app.sh` | Release 构建,输出 `build/Ops Notch.app` |
| `scripts/`(复数) | `run_dev.sh` | `swift run OpsNotch` 裸进程运行 |
| `scripts/`(复数) | `static_checks.py` | 静态检查,见「测试与 CI」 |

### swift run 与打包 .app 的差异

`swift run` / `scripts/run_dev.sh` 启动的是裸进程,不是完整 App Bundle:登录项(`SMAppService.mainApp`)与刘海 / Sensor 相关行为只有在打包后的 `.app` 中才符合正式表现。涉及登录项、多显示器、拖放、剪贴板的功能,请一律用 `./script/build_and_run.sh` 或 `./scripts/build_app.sh` 的产物验收。

## 打包 .app

```bash
./scripts/build_app.sh
open "build/Ops Notch.app"
```

Release 构建输出 `build/Ops Notch.app`,使用 ad-hoc codesign,适合本地开发。正式分发需要替换为 Developer ID 签名并做 notarization。

## 测试与 CI

```bash
swift test                          # Core 单元测试:旧格式迁移、Pinned 排序、搜索、Recent TTL、Reference / Copy-in、Safe Action 边界
python3 scripts/static_checks.py    # 静态检查
```

`static_checks.py` 扫描所有 `.swift` / `.json` / `.plist` 文件:阻止 `tauri` / `react` / `vite` 等遗留词回归,并锚定关键 AppKit API 调用点(拖放注册类型、`changeCount`、`NSScreen.screens`、`QLPreviewPanel` 等)。

CI(`.github/workflows/package-app.yml`,「macOS 打包」)只在推送 `v*` 标签或手动触发时运行,普通 push 不触发。步骤:`swift test` → `static_checks.py` → `scripts/build_app.sh` → `codesign --verify` → zip 上传 Artifact;`v*` 标签触发时额外创建 GitHub Release 附 zip(arm64、ad-hoc 签名未公证,首次打开需右键 App → 打开)。

## 实机验收

真实多显示器、拖放、剪贴板行为无法在单元测试或 CI 中覆盖,请按 [VERIFY_ON_MAC.md](VERIFY_ON_MAC.md) 的清单实机验证。

## 数据位置

```text
~/Library/Application Support/lab.hutong.opsnotch/
├── shelf.json
└── shelf-files/
```

与旧版 V0.x / V1.x 共用同一数据目录:旧 `shelf.json`(含早期根数组格式、`ip` / `command` 类型)自动迁移为 Text,一般无需搬数据。迁移注意事项与备份建议见 [MIGRATION_FROM_TAURI.md](MIGRATION_FROM_TAURI.md)。

## 文档索引

| 文档 | 内容 |
|---|---|
| [AGENTS.md](AGENTS.md) | 工程约定:目录结构、架构规则、CI 关卡与已知陷阱 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | V2 架构设计:Sensor / 多显示器 / 剪贴板 / 数据安全 |
| [FEATURE_MATRIX.md](FEATURE_MATRIX.md) | V1.x → V2 功能对照表 |
| [VERIFY_ON_MAC.md](VERIFY_ON_MAC.md) | macOS 实机验收清单 |
| [MIGRATION_FROM_TAURI.md](MIGRATION_FROM_TAURI.md) | 从 Tauri V1.x 迁移与数据兼容说明 |
| [CHANGELOG_V2.0.1.md](CHANGELOG_V2.0.1.md) | 版本变更记录 |

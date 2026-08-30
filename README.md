# Ops Notch Native V2.0.1

Ops Notch 已从 Tauri / React / Vite 重构为 **macOS 原生应用**：

- **Swift**：业务与数据模型
- **AppKit**：刘海 Sensor、窗口、多显示器、拖放、剪贴板、状态栏、Quick Look、Finder
- **SwiftUI**：Shelf 内容、Pinned / Recent、搜索、编辑、设置
- **Swift Package Manager**：无 Node.js、无 npm、无 Vite、无 localhost

最低系统：**macOS 13**；建议 Xcode 15+ / Swift 5.9+。

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

平时主 Shelf 窗口完全隐藏。每块显示器顶部有一个透明 AppKit Sensor；在哪块屏幕触发，就在哪块屏幕打开 Shelf。

## 已实现

- 多显示器独立 Sensor
- 显示器插拔 / 排列 / 分辨率变化自动重建
- 鼠标触碰顶部自动展开 Shelf
- AppKit `NSDraggingDestination` 原生接收：
  - 文件
  - 文件夹
  - 多文件
  - URL
  - `public.utf8-plain-text` / 选中文字
- 三指拖移：只要来源 App 发出系统 Drag Pasteboard，Sensor 可接收
- Clipboard Catch：复制文字后碰刘海自动进入 Recent
- Clipboard `changeCount` 去重
- 点击 Text → Copy
- File / Folder → Open
- URL → Browser
- Application → Launch
- Safe Action：仅本地绝对路径或 HTTP/HTTPS
- Quick Look
- Reveal in Finder
- 原生拖出；多选后拖动 Handle 可发起多项目 Drag Session
- Pinned / Recent
- 搜索
- Recent TTL 自动清理
- Reference / Copy-in
- JSON 本地存储
- 兼容旧版 V0.x / V1.x `shelf.json` 主要字段
- 中英文运行时切换
- 所有显示器 / 鼠标屏幕 / 主屏 / 最近屏幕
- 登录启动：`SMAppService.mainApp`
- 原生菜单栏：`NSStatusItem` + SF Symbol
- 无 Dock 图标：Accessory activation policy
- 无自定义全局快捷键

## 数据位置

继续沿用旧版本数据目录：

```text
~/Library/Application Support/lab.hutong.opsnotch/
├── shelf.json
└── shelf-files/
```

所以从 Tauri V1.x 切换到 Native V2 时，正常情况下不需要搬数据。

## 开发运行

### Xcode

```bash
xed .
```

Xcode 会直接识别 `Package.swift`，选择 `OpsNotch` scheme 后 Run。

### 命令行

```bash
swift test
swift build
./script/build_and_run.sh
```

原生版本不会启动：

```text
http://localhost:1420
```

也不需要 Node.js / npm。

## 打包 `.app`

在 macOS：

```bash
./scripts/build_app.sh
```

生成：

```text
build/Ops Notch.app
```

运行：

```bash
open "build/Ops Notch.app"
```

脚本会使用 ad-hoc codesign，适合本地开发。正式分发需要替换成 Developer ID 签名并做 notarization。

> 登录启动请使用打包后的 `.app` 测试；`swift run` 不是完整 App Bundle，`SMAppService.mainApp` 在开发裸进程中不代表正式行为。

## 测试

```bash
swift test
python3 scripts/static_checks.py
```

当前 Core 单元测试覆盖：

- 旧 `ip` / `command` 类型迁移为 Text
- V0.1 根数组格式迁移
- Pinned 排序
- Search
- Recent TTL
- Reference 删除不删除原文件
- Copy-in 删除只删除托管副本
- Safe Action 安全边界

真实 macOS 原生窗口 / AppKit Drag / 多显示器必须按 `VERIFY_ON_MAC.md` 实机验证。


## V2.0.1 开发入口

推荐统一使用：

```bash
./script/build_and_run.sh
```

调试/日志：`--debug`、`--logs`、`--telemetry`、`--verify`。

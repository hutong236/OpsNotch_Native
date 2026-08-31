# Ops Notch

<p align="center">
  <strong>把文件、文字与链接暂存在 macOS 刘海边缘，需要时即刻取回。</strong>
</p>

<p align="center">
  <a href="https://github.com/hutong236/OpsNotch_Native/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/hutong236/OpsNotch_Native/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/hutong236/OpsNotch_Native/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/hutong236/OpsNotch_Native"></a>
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-black">
  <img alt="Swift 5.9+" src="https://img.shields.io/badge/Swift-5.9%2B-F05138">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-blue"></a>
</p>

<p align="center">
  简体中文 · <a href="README.en.md">English</a>
</p>

Ops Notch 是一款原生 macOS 快速暂存工具。将文件、文件夹、URL 或选中文字拖到任意显示器顶部的透明感应区，即可收入 Shelf；复制文字后触碰感应区，内容会自动进入 Recent。应用平时隐藏 Dock 图标，只保留菜单栏入口。

## 下载与安装

1. 从 [Latest Release](https://github.com/hutong236/OpsNotch_Native/releases/latest) 下载 macOS 压缩包。
2. 解压后将 Ops Notch.app 移入 Applications。
3. 当前发布包采用 ad-hoc 签名、尚未公证；首次启动请右键应用并选择“打开”。

当前自动发布产物面向 Apple Silicon（arm64）。Intel Mac 用户可按“从源码构建”自行编译。

## 核心能力

| 能力 | 说明 |
|---|---|
| 原生拖放 | 接收文件、文件夹、多文件、应用、URL 和系统文字拖拽 |
| Clipboard Catch | 触碰顶部感应区时读取新复制的文字，并按剪贴板 changeCount 去重 |
| 快速取回 | 搜索、类型筛选、键盘上下选择、Enter 复制、Space 预览、Esc 收起 |
| 条目管理 | Pinned / Recent、编辑、删除、多选复制、Recent TTL 自动清理 |
| 文件策略 | Reference 保留原路径；Copy-in 将文件复制到应用数据目录 |
| 多显示器 | 每块屏幕独立感应区，支持热插拔、排列和分辨率变化 |
| 系统集成 | 菜单栏、登录启动、Quick Look、中英文切换、可选全局呼出热键 |
| 安全边界 | 只允许打开本地绝对路径和 HTTP/HTTPS URL，不执行 Shell、SSH 或任意命令 |

## 使用方式

### 放入 Shelf

- 从 Finder 拖入文件、文件夹或应用。
- 从浏览器拖入网页地址或链接。
- 从支持系统拖拽的应用拖入选中文字。
- 复制文字后，将鼠标移动到任意显示器顶部中央，由 Clipboard Catch 收入 Recent。

### 取回内容

- 点击文字或 URL 条目可复制内容。
- 文件、文件夹和应用可复制为原生文件对象，也可打开、Quick Look 或在 Finder 中显示。
- 在设置中录制可选全局热键后，可从其他应用快速呼出 Shelf。
- 使用 Command+1 至 Command+5 切换类型筛选；方向键选择，Enter 复制，Space 预览，Esc 收起。

## 技术实现

| 层 | 职责 |
|---|---|
| OpsNotchCore | 数据模型、排序筛选、持久化、迁移与安全校验 |
| AppKit | 顶部感应区、窗口、多显示器、拖放、剪贴板、菜单栏与 Quick Look |
| SwiftUI | Shelf 内容、搜索筛选、编辑与设置界面 |
| Swift Package Manager | 依赖、构建和测试；项目不需要 Node.js 或本地 Web 服务 |

架构约束和数据流详见 [ARCHITECTURE.md](ARCHITECTURE.md)。

## 从源码构建

要求：

- macOS 13 或更高版本
- Swift 5.9 或更高版本
- 建议使用 Xcode 15 或更高版本

开发检查：

    swift test
    swift build
    python3 scripts/static_checks.py

构建并启动完整 App Bundle：

    ./script/build_and_run.sh

构建 Release 版：

    ./scripts/build_app.sh
    open "build/Ops Notch.app"

直接运行 swift run 得到的是裸进程。登录项、刘海感应区和部分系统集成行为应使用完整 App Bundle 验证。

## 项目结构

| 路径 | 内容 |
|---|---|
| Sources/OpsNotchCore | 无 UI 依赖的核心逻辑 |
| Sources/OpsNotchApp | AppKit 系统层与 SwiftUI 内容层 |
| Tests/OpsNotchCoreTests | 核心逻辑单元测试 |
| scripts | 构建、运行与静态检查脚本 |
| script | 日常构建、打包与调试入口 |
| openspec | 已实现能力的规格和历史变更记录 |
| .github | CI、发布、Issue 与 PR 协作配置 |

## 数据与隐私

数据保存在本机：

    ~/Library/Application Support/lab.hutong.opsnotch/
    ├── shelf.json
    └── shelf-files/

项目不启动本地 Web 服务，也不提供任意命令执行能力。旧版数据迁移与备份说明见 [MIGRATION_FROM_TAURI.md](MIGRATION_FROM_TAURI.md)。

## 质量与发布

Pull Request 会运行 Core 单元测试、Debug 构建和静态架构检查。main 分支构建会生成可下载的 Actions Artifact；推送符合 vX.Y.Z 的标签会自动校验版本并创建 GitHub Release。

真实多显示器、跨应用拖放、剪贴板和登录项行为无法完全由 CI 覆盖，发布前请完成 [VERIFY_ON_MAC.md](VERIFY_ON_MAC.md) 中的实机清单。

## 文档

- [贡献指南](CONTRIBUTING.md)
- [架构说明](ARCHITECTURE.md)
- [功能矩阵](FEATURE_MATRIX.md)
- [变更记录](CHANGELOG.md)
- [macOS 实机验收](VERIFY_ON_MAC.md)
- [安全政策](SECURITY.md)
- [支持说明](SUPPORT.md)
- [行为准则](CODE_OF_CONDUCT.md)

## 贡献

欢迎提交问题、改进建议和 Pull Request。开始前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。涉及感应区、窗口、剪贴板或数据格式的改动，请同时阅读架构和迁移文档。

## 许可证

本项目使用 [MIT License](LICENSE)。
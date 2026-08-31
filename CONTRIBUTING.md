# 贡献指南

感谢你愿意参与 Ops Notch。为了让评审和发布保持可控，请在提交前遵循以下约定。

## 开始之前

- 可复现缺陷请使用 Bug 模板。
- 新功能请先提交 Feature Request，说明使用场景、预期交互和边界。
- 安全问题不要公开提交 Issue，请按 SECURITY.md 处理。
- 大型改动应先讨论设计，再开始实现。

## 开发环境

要求 macOS 13+、Swift 5.9+，建议使用 Xcode 15+。

    git clone https://github.com/hutong236/OpsNotch_Native.git
    cd OpsNotch_Native
    swift test
    swift build
    python3 scripts/static_checks.py

需要验证完整系统行为时运行：

    ./script/build_and_run.sh

## 分支与提交

建议分支命名：

- feat/short-description
- fix/short-description
- docs/short-description
- refactor/short-description

提交信息采用简洁的 Conventional Commits 风格，例如：

- feat: add a shelf interaction
- fix: prevent duplicate clipboard capture
- docs: clarify release installation
- test: cover legacy data migration
- ci: tighten release validation

每个提交应聚焦一个逻辑变更，避免混入无关格式化或生成文件。

## 架构约束

- 依赖方向只能是 OpsNotchApp 指向 OpsNotchCore。
- OpsNotchCore 不得导入 AppKit 或 SwiftUI。
- 顶部感应区、窗口、拖放、剪贴板和菜单栏由 AppKit 管理；SwiftUI 负责内容界面。
- 条目动作必须经过 SafeActionValidator.validate。
- 不得加入 Shell、SSH、kubectl 或任意命令执行能力。
- 必须保持旧 shelf.json 格式的兼容迁移。
- 新增界面文本时必须同时补齐中文和英文词典。
- 全局热键必须保持可选、默认关闭，并使用不需要 Input Monitoring 权限的注册式实现。

修改 SensorManager、ClipboardManager 或 ShelfWindowController 前请阅读 ARCHITECTURE.md；修改存储格式前请阅读 MIGRATION_FROM_TAURI.md。

## 测试要求

提交 Pull Request 前至少运行：

    swift test
    swift build
    python3 scripts/static_checks.py

涉及 UI 或系统集成时，还应按 VERIFY_ON_MAC.md 完成对应的实机项目，并在 PR 中记录：

- 测试的 macOS 版本与芯片架构。
- 单屏或多屏环境。
- 已验证的拖放来源应用。
- 是否验证 Clipboard Catch、Quick Look、登录项与全局热键。
- 如有视觉变化，附截图或短视频。

## Pull Request

PR 描述应包含：

- 问题与目标。
- 实现方式和关键取舍。
- 测试证据。
- 数据兼容、安全或权限影响。
- 用户可见变化和文档更新。

维护者可能要求拆分范围、补充测试或先完成 OpenSpec 设计。提交代码即表示你同意其按项目 MIT License 发布。
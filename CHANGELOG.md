# 变更记录

本文件记录 Ops Notch 的用户可见变化。版本遵循语义化版本，正式发行以 GitHub Releases 为准。

## 未发布

### 新增

- Ops Notch 3.0 使用 Command-first Quick Shelf：统一搜索 Clipboard、Favorites、Finder、Desktop 命令与安全操作，并加入 Context / Now / Favorites / Recent / Results 智能分区。
- 新增动态 Inspector、显式 Peek / Expanded / Drop Target / Confirmation 状态，以及统一的键盘导航与动作路由。
- 设置窗口改为原生 Sidebar 信息架构，并加入统一 Design System、Reduce Motion、Increase Contrast 与 VoiceOver 友好交互。
- 增加 Snapshot / Smart Shelf ranking 缓存回归测试、UI polling 防回退规则与 8–24 小时长稳性能验收模板。

### 发布工程

- 发布工作流支持 `v3.0.0-beta.N`、`v3.0.0-rc.N` 与 `v3.0.0`；Beta/RC 会创建 GitHub Prerelease。
- Prerelease Git tag 与 macOS Bundle 版本分离：例如 `v3.0.0-beta.1` 的 Bundle 仍使用 numeric `3.0.0 (300)`。

### 移除

- 移除菜单栏隐藏图标、持续隐藏区、隐藏图标面板及其辅助功能扫描/代理点击能力；Ops Notch 保留普通菜单栏入口。

### 改进

- Finder 快捷路径的系统默认模式改为直接打开，不再执行 AppleScript 窗口预检。
- “优先 Tab”把窗口复用与新建 Tab 合并为一次自动化调用，减少等待与进程启动开销。

## 2.2.2 - 2026-08-31

### 修复

- 修复标签版本向 App Bundle 注入和校验的发布流程。
- 正式产物现在校验 CFBundleShortVersionString 与 CFBundleVersion。

## 2.2.1 - 2026-08-30

### 改进

- 拖拽进入时仅显示 Drop Drawer。
- 放入成功后显示确认反馈并自动收起。

## 2.2.0 - 2026-08-30

### 新增

- 已展开 Shelf 和 Drop 提示条均可接收落放。
- 文件、文件夹与应用复制为原生文件对象。
- 类型筛选、键盘取回流和可选全局呼出热键。
- 条目浮动预览和最近使用排序改进。

### 修复

- 修复取消置顶、选择复制、Tab 重聚焦和行内按钮命中问题。
- 保持应用自身复制不回灌 Clipboard Catch。

## 2.1.0 - 2026-08-30

### 改进

- 发布工作流从 vX.Y.Z 标签注入版本号。
- 开发版保留为 Actions Artifact，正式版统一通过 GitHub Release 分发。

## 2.0.1

- 完成原生 Swift、AppKit 与 SwiftUI 主线。
- 加入统一的开发构建、日志、调试和验证脚本。

更早的 2.0.1 说明保留在 CHANGELOG_V2.0.1.md。

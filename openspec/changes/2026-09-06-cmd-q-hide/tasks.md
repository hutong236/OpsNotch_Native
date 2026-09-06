# Tasks

- [x] 明确 `⌘Q` 与状态栏“退出”的两种不同语义。
- [x] 替换 SwiftUI 默认 app termination command，让 `⌘Q` 执行隐藏。
- [x] 保持状态栏“退出”继续真实终止应用。
- [x] 确认实现不使用 `applicationShouldTerminate` 全局拦截系统终止。
- [x] 通过 GitHub Actions 执行 Core tests、Debug build、Architecture checks。
- [ ] 在 macOS `.app` 包中手工验证隐藏、重新唤醒和右键退出。

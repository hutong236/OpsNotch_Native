# Ops Notch Native V2.0.1

V2.0.1 是 Native V2 主线的第一个维护版本，功能基线与 V2.0.0 一致，并补齐原生 macOS 开发运行工作流：

- 保持 Swift + AppKit + SwiftUI 单一原生技术栈。
- 保留多显示器 Sensor、原生文字/文件拖放、Clipboard Catch、Pinned/Recent、Quick Look、状态栏和设置。
- 新增 `script/build_and_run.sh`，统一 kill → build → 生成 `.app` → launch。
- 支持 `--debug`、`--logs`、`--telemetry`、`--verify`。
- 新增 `.codex/environments/environment.toml` Run action。
- App 版本更新为 2.0.1 / build 201。

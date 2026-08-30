# 任务:重新生成 README

## 1. 事实校准

- [x] 1.1 通读 `script/build_and_run.sh`、`scripts/build_app.sh`、`scripts/run_dev.sh`、`scripts/static_checks.py`,记录每个脚本的实际用法、参数与输出路径,作为 README 命令节的唯一依据;验证:笔记中每条命令都能在脚本源码中找到对应行
- [x] 1.2 通读 `.github/workflows/macos-ci.yml`、`Package.swift`、`Info.plist`,确认 CI 步骤、目标产物、平台版本与 `Info.plist` 中的 Bundle 标识;验证:CI 四步与 Package.swift 目标列表已记录且相互一致

## 2. 重写 README

- [x] 2.1 按设计的章节结构(简介 → 核心交互 → 功能概览 → 环境要求 → 开发运行 → 打包 → 测试与 CI → 实机验收 → 数据位置 → 文档索引)重写 `README.md`,标题不含版本号;验证:`grep -n "V2\.0" README.md` 标题行无硬编码版本
- [x] 2.2 功能概览压缩为概览级并链接 `FEATURE_MATRIX.md`,架构简述链接 `ARCHITECTURE.md`,新增「文档索引」表格覆盖 `AGENTS.md`、`ARCHITECTURE.md`、`VERIFY_ON_MAC.md`、`MIGRATION_FROM_TAURI.md`、`FEATURE_MATRIX.md`、`CHANGELOG_V2.0.1.md`;验证:索引中每个相对链接指向的文件真实存在(`ls` 逐个核对)
- [x] 2.3 写入 `script/`(单数)与 `scripts/`(复数)分工说明及 `--debug/--logs/--telemetry/--verify` 变体;验证:说明与 1.1 笔记一致,示例命令可直接复制执行
- [x] 2.4 写入「测试与 CI」一节(CI 四步 + static_checks 用途一句话)与 `swift run` 裸进程 vs 打包 `.app` 的差异边界(登录项 `SMAppService`、Sensor 行为);验证:CI 步骤列表与 1.2 记录的 workflow 内容一致

## 3. 校验与收尾

- [x] 3.1 逐条核对 README 中出现的每个文件路径、目录、命令与仓库实际一致;验证:命令核对清单全部打勾,无凭记忆写入的路径
- [x] 3.2 确认变更未误伤其他文件:`git diff --stat` 仅出现 `README.md`(及 openspec 变更目录);验证:`git status` 无意外改动
- [x] 3.3 运行 `python3 scripts/static_checks.py` 与 `swift build` 确认仓库健康;验证:两者均退出码 0

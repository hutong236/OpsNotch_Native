# 提案:重新生成 README

## Why

当前 `README.md` 与仓库现状存在多处偏差和结构问题,作为项目入口文档已经不可靠:

- 标题硬编码版本号 `V2.0.1`,会随版本漂移,且仓库已有 `CHANGELOG_V2.0.1.md` 承载版本信息。
- 完全没有提到 CI(`.github/workflows/macos-ci.yml`)和静态检查关卡(`scripts/static_checks.py` 的 API 锚点约束),新贡献者不知道 CI 会检查什么。
- 没有文档索引:仓库还有 `ARCHITECTURE.md`、`VERIFY_ON_MAC.md`、`MIGRATION_FROM_TAURI.md`、`FEATURE_MATRIX.md`、`AGENTS.md`,README 未指向它们。
- `script/`(单数)与 `scripts/`(复数)两个目录分工(`build_and_run.sh` vs `build_app.sh`/`run_dev.sh`/`static_checks.py`)是已知易混点,README 未说明。
- 「已实现」功能清单与 `FEATURE_MATRIX.md` 大量重复,两处要分别维护。
- 未说明 `swift run` 与打包 `.app` 的行为差异边界(只在注释里提了一句 login item)。

需要重新生成一份与当前代码、脚本、CI 完全一致的中文 README,恢复其作为项目唯一准确入口的作用。

## What Changes

- **重写 `README.md`**,按新结构组织:项目简介 → 核心交互 → 功能概览 → 环境要求 → 开发运行 → 打包 `.app` → 测试与 CI → 实机验收 → 数据位置 → 文档索引。
- **事实校准**:所有命令、路径与仓库实际一致(含 `script/` 与 `scripts/` 的分工说明、`--debug/--logs/--telemetry/--verify` 变体)。
- **去重**:功能明细链接到 `FEATURE_MATRIX.md`,架构细节链接到 `ARCHITECTURE.md`,README 只保留概览级内容。
- **版本信息**:标题不再硬编码版本号,版本/变更指向 `CHANGELOG_V2.0.1.md`。
- **补充缺失内容**:CI 工作流内容、静态检查说明、文档索引、`swift run` vs 打包 `.app` 的差异边界。
- **保持中文**(项目文档语言约定,见 AGENTS.md)。
- 纯文档变更:不修改任何源代码、脚本、CI 配置。

## Capabilities

### New Capabilities

(无)

### Modified Capabilities

(无)

本变更为纯文档重写,不改变任何运行时行为,无需 spec delta;已在 `.openspec.yaml` 中设置 `skip_specs: true`。

## Impact

- **受影响文件**:仅 `README.md`(整文件重写)。
- **不受影响**:`Sources/`、`Tests/`、`Package.swift`、两个脚本目录、CI workflow、`openspec/`。
- **CI 影响**:无。`scripts/static_checks.py` 只扫描 `.swift`/`.json`/`.plist` 文件,不扫描 `.md`。
- **验收方式**:README 中每条命令、路径、链接逐一与仓库实际内容核对;`python3 scripts/static_checks.py` 与 `swift build` 保持通过(证明变更未误伤其他文件)。

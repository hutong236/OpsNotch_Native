# 设计:重新生成 README

## Context

动机见 proposal.md。当前 `README.md` 的内容基础仍然可用(技术事实大部分正确,如 Swift/AppKit/SwiftUI 分工、数据目录、Safe Action 约束),问题在于结构、重复、缺失(CI、文档索引、`script/` vs `scripts/` 说明)和硬编码版本号。本设计只处理文档本身,不触及任何代码。

写作时必须依据的**事实来源**(README 中每条陈述都应能追溯到其中之一):

| 事实 | 来源 |
|---|---|
| 构建/测试/打包命令、脚本行为 | `script/build_and_run.sh`、`scripts/build_app.sh`、`scripts/run_dev.sh`、`scripts/static_checks.py` |
| CI 关卡 | `.github/workflows/macos-ci.yml` |
| 目标/产物/平台 | `Package.swift`(macOS 13、OpsNotchCore 库 + OpsNotchApp 可执行) |
| 架构与模块职责 | `ARCHITECTURE.md`、`AGENTS.md` |
| 功能对照 | `FEATURE_MATRIX.md` |
| 数据存储 | `AGENTS.md` / `MIGRATION_FROM_TAURI.md`(`~/Library/Application Support/lab.hutong.opsnotch/`) |
| 实机验收 | `VERIFY_ON_MAC.md` |
| 版本/变更 | `CHANGELOG_V2.0.1.md` |

## Goals / Non-Goals

**Goals:**

- README 结构化为「概览 + 入口」:读者 1 分钟能看懂项目是什么、怎么跑;细节通过文档索引跳转。
- 全文事实与仓库当前状态一致,每条命令可直接复制执行。
- 明确两个易混点:① `script/`(单数,开发入口 `build_and_run.sh`)与 `scripts/`(复数,`build_app.sh`/`run_dev.sh`/`static_checks.py`)的分工;② `swift run`/`swift build` 裸进程 vs 打包 `.app` 的行为差异(登录项、刘海/Sensor)。
- 保持中文,风格与 `ARCHITECTURE.md` 等现有文档一致。

**Non-Goals:**

- 不新增英文版 README、不加徽章(badge)、不引入 screenshots(截图需实机,属 VERIFY_ON_MAC 范畴)。
- 不修改 `FEATURE_MATRIX.md`、`ARCHITECTURE.md` 等任何其他文档。
- 不改 `scripts/static_checks.py` 的扫描范围或规则。

## Decisions

1. **README 定位为「入口 + 概览」,明细外链。**
   功能清单只保留一句话级别的概览并链接 `FEATURE_MATRIX.md`;架构只放一张模块分层简述并链接 `ARCHITECTURE.md`。
   *备选*:维持全文自包含。放弃原因:与 FEATURE_MATRIX/ARCHITECTURE 双份维护,正是本次要消除的漂移源。

2. **标题不含版本号**(`# Ops Notch Native`),版本/变更指向 `CHANGELOG_V2.0.1.md`。
   *备选*:保留 `V2.0.1`。放弃原因:每次发版都要改两处,漂移风险高。

3. **保留「核心交互」ASCII 示意图**。它对新读者解释产品模型(拖拽到 Sensor → Shelf;⌘C → 碰 Sensor → Clipboard Catch)最直观,且无图可替代(Non-Goal 排除截图)。

4. **新增「测试与 CI」一节**,列出 CI 四步(`swift test`、`swift build`、`static_checks.py`、`build_app.sh`)并说明 static_checks 的存在意义(API 锚点防回归),但不复述其全部规则——规则细节以脚本本体和 AGENTS.md 为准。

5. **新增「文档索引」一节(表格)**:每个文档一行,写明职责与何时读。包含 `AGENTS.md`(贡献约定)、`ARCHITECTURE.md`、`VERIFY_ON_MAC.md`、`MIGRATION_FROM_TAURI.md`、`FEATURE_MATRIX.md`、`CHANGELOG_V2.0.1.md`。

## Risks / Trade-offs

- [文档再次漂移] → README 只写概览与可执行命令,所有易变明细外链单一来源;命令均从脚本/CI 文件核对而非凭记忆。
- [命令写错导致用户照抄失败] → 任务清单包含逐条运行验证(允许只读验证,如 `--help`、路径核对;破坏性操作只核对不执行)。
- [误伤其他文件] → 变更仅允许触碰 `README.md`;收尾用 `git diff --stat` 复核。

## Migration Plan

单文件重写,无部署/回滚问题;如需回滚 `git checkout -- README.md` 即可。

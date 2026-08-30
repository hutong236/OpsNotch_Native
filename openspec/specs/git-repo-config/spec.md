# git-repo-config Specification

## Purpose

定义 OpsNotch_Native 仓库的 Git 基线约定:哪些文件永不入库(构建产物、系统/编辑器噪声)、已误入库的产物如何退出跟踪、以及行尾与二进制属性如何约束,保证提交历史只包含源码与可评审的文本资产。

## Requirements

### Requirement: 构建产物必须不被跟踪

仓库 MUST 通过 `.gitignore` 忽略所有本地构建输出,至少包括:`dist/`、`build/`、`DerivedData/`、`*.dSYM`。任何一次本地打包(`script/build_and_run.sh`、`scripts/build_app.sh`)之后,这些目录下的新增文件 MUST NOT 出现在 `git status` 中。

#### Scenario: 打包后 git status 干净

- **WHEN** 在仓库根目录执行 `./script/build_and_run.sh` 生成 `dist/Ops Notch.app` 后运行 `git status --short`
- **THEN** 输出中不包含任何 `dist/` 路径的未跟踪条目

#### Scenario: 忽略规则可被 git 识别

- **WHEN** 对 `dist/`、`build/`、`DerivedData/` 分别执行 `git check-ignore -v <路径>`
- **THEN** 每个路径均命中 `.gitignore` 中的对应规则

### Requirement: 系统与编辑器噪声文件必须被忽略

`.gitignore` MUST 覆盖 macOS 系统文件(`.DS_Store`、`._*`、`.AppleDouble`、`.Spotlight-V100`、`.Trashes`)与常见编辑器目录(`.idea/`、`.vscode/`),以及 Xcode/SwiftPM 用户态文件(`xcuserdata/`、`*.xcuserstate`、`.swiftpm/`、`.build/`)。

#### Scenario: 任意层级出现 .DS_Store 不产生未跟踪条目

- **WHEN** 仓库任意子目录中出现 `.DS_Store` 并运行 `git status --short`
- **THEN** 输出中不包含该 `.DS_Store`

### Requirement: 已入库的构建产物必须退出跟踪

首次提交中已跟踪的 `dist/**` 文件 MUST 通过仅操作索引的方式(`git rm -r --cached`)取消跟踪:提交后 `git ls-files dist` 输出为空,同时工作区中的 `dist/Ops Notch.app` 文件保持存在且内容不变。

#### Scenario: 索引中不再包含 dist

- **WHEN** 清理提交完成后执行 `git ls-files dist`
- **THEN** 输出为空,且 `dist/Ops Notch.app/Contents/MacOS/OpsNotch` 仍存在于工作区

### Requirement: 行尾与二进制属性约定

仓库 MUST 包含 `.gitattributes` 约束:文本文件行尾自动规范化(`* text=auto`);`*.sh` 强制 LF;`*.png`、`*.icns` 标记为二进制(`binary`),禁止文本合并与行尾转换。

#### Scenario: 属性声明可被 git 识别

- **WHEN** 执行 `git check-attr text eol binary -- "*.sh" "*.png" "*.icns"`
- **THEN** `*.sh` 声明为 text(auto/lf 约束),`*.png` 与 `*.icns` 声明为 binary

### Requirement: 清理不得影响既有约定与历史

本变更 MUST NOT 修改任何 Swift 源码、`script(s)/` 脚本逻辑、CI 工作流或已提交历史(不使用 force 重写);`.codex/`、`.zcode/` 目录保持跟踪状态不变。

#### Scenario: CI 基线不受影响

- **WHEN** 清理提交推送后 CI(`swift test`、`swift build`、`static_checks.py`、`build_app.sh`)运行
- **THEN** 全部步骤通过,与变更前行为一致

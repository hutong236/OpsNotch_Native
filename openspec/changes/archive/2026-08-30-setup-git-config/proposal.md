# Proposal: setup-git-config

## Why

仓库已完成首次提交,但 Git 基础配置不完整:`.gitignore` 仅有 5 条最小规则,而打包脚本(`script/build_and_run.sh`)输出的 `dist/Ops Notch.app`(含 Mach-O 可执行文件、icns 资源与代码签名)已被误提交跟踪。构建产物入库会导致每次打包后出现无意义的二进制 diff、仓库体积膨胀,并污染 code review;同时缺少 `.gitattributes`,行尾与二进制策略没有约束。

## What Changes

- 完善 `.gitignore`,补齐四类忽略项:
  - 构建产物:`dist/`(当前缺失)、`build/`(已有)、`DerivedData/`、`*.dSYM`;
  - Xcode / SwiftPM 用户态文件:`xcuserdata/`、`*.xcuserstate`(已有)、`Package.resolved` 保持跟踪决策见 design(本项目无第三方依赖,暂无该文件);
  - macOS 系统文件:`.DS_Store`(已有),补充 `._*`、`.AppleDouble`、`.Spotlight-V100`、`.Trashes`;
  - 编辑器目录:`.idea/`、`.vscode/`。
- 将已跟踪的 `dist/Ops Notch.app/**`(4 个文件)从 git 索引移除(`git rm -r --cached`),工作区文件保留。
- 新增 `.gitattributes`:统一行尾策略(`* text=auto`,shell 脚本强制 LF),标记二进制文件(`*.png`、`*.icns`、`*.icns` 资源与 Mach-O)。
- 核查仓库级 git 配置(默认分支 `main`、user.name/user.email 已配置),确认无需改动并记录结论。
- 明确不做的事:不移除 `.codex/`、`.zcode/` 等 AI 工具配置的跟踪(首次提交刻意纳入,视为共享项目配置);不改任何 Swift 源码、脚本逻辑与 CI 工作流。

## Capabilities

### New Capabilities

- `git-repo-config`: Git 仓库的忽略策略、跟踪规则(哪些产物永不入库)与行尾/二进制属性约定,作为后续所有提交的基线约束。

### Modified Capabilities

(无 — 仓库尚无任何主规格)

## Impact

- **文件变更**:根目录 `.gitignore`(修改)、`.gitattributes`(新增)。
- **git 索引**:`dist/` 下 4 个文件取消跟踪;需要一次清理提交。
- **不受影响**:`Sources/`、`Tests/`、`script(s)/` 逻辑、`.github/workflows/macos-ci.yml`(CI 不引用 `dist/`,且 `build/` 已被忽略);`scripts/static_checks.py` 只扫描 `.swift`/`.json`/`.plist`,不受本变更影响。
- **风险**:对已提交的二进制文件取消跟踪属于历史无关的索引操作,不影响既有提交历史;团队其他机器执行 `git pull` 后需要留意 `dist/` 在本地保留但不再跟踪。

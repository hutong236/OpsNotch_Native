# Design: setup-git-config

## Context

仓库已有一次提交(`main`,62 个跟踪文件):`.gitignore` 仅 5 条(`.build/`、`build/`、`.DS_Store`、`*.xcuserstate`、`.swiftpm/`),无 `.gitattributes`;`dist/Ops Notch.app/**`(含 Mach-O 可执行文件、`AppIcon.icns`、`_CodeSignature/CodeResources`)已被跟踪。现状核实:`Package.swift` 无第三方依赖(不存在 `Package.resolved`);扫描确认所有已提交文本文件均为 LF、无 CRLF;CI 为 `swift test` / `swift build` / `static_checks.py` / `build_app.sh`,不引用 `dist/`。动机见 proposal.md 的 Why,需求基线见 `specs/git-repo-config/spec.md`。

## Goals / Non-Goals

**Goals:**

- 打包后 `git status` 保持干净:构建产物、系统/编辑器噪声全部被忽略。
- 用最小索引操作让已入库的 `dist/` 退出跟踪,不触碰历史。
- 行尾策略一次定义到位,shell 脚本在任何编辑环境下保持 LF。
- 所有决策可在实施后用 `git check-ignore` / `git check-attr` / `git ls-files` 验证。

**Non-Goals:**

- 不重写 git 历史(无 filter-branch/filter-repo)。
- 不修改全局或仓库级 `core.autocrlf` 等本地 git config(`.gitattributes` 已覆盖行尾语义)。
- 不改 `.codex/`、`.zcode/` 的跟踪状态,不改动 `SOURCE_SHA256SUMS.txt`(源码校验清单,非构建产物)。
- 不引入 commit hooks / issue / PR 模板等新流程设施。

## Decisions

1. **退出跟踪与忽略规则放在同一次提交**:`.gitignore` 增加 `dist/` 与 `git rm -r --cached "dist"` 同步进行。若只 ignore 不清理,索引继续膨胀且 `git status` 语义混乱;若依赖后续大扫除则留下长期脏状态。备选(重写历史从库中抹除二进制)被否:收益仅是体积,代价是破坏单提交历史与协作。
2. **`.gitignore` 采用追加而非重写**:保留现有 5 条规则原样,新增构建产物(`dist/`、`DerivedData/`、`*.dSYM`)、macOS 噪声(`._*`、`.AppleDouble`、`.Spotlight-V100`、`.Trashes`)、编辑器目录(`.idea/`、`.vscode/`)、`xcuserdata/`。降低覆盖既有意图的风险。
3. **行尾用 `* text=auto` 全局规范化**而非逐类型列举:已核实现存文本文件全为 LF,renormalize 无实际 diff;这是 git 官方推荐的跨平台基线。备选(仅对 `.swift`/`.md` 声明 `text`)覆盖不全,`yml`/`plist`/`py` 会漏。
4. **`*.sh text eol=lf` 强制 LF**:防止脚本未来在任何带 CRLF 习惯的编辑器中被破坏(CI 在 bash 上执行,此风险真实存在)。不设 `eol=crlf` 任何条目。
5. **`*.png` / `*.icns` 用 `binary` 宏**(等价 `-text -diff -merge`):一次禁掉行尾转换、文本 diff 与合并冲突解决,比仅 `-text` 更稳。Assets 与 dist 内 icns 均受益。
6. **不特判 `Package.resolved`**:当前包无依赖,文件不存在。将来引入依赖时需注意 `.swiftpm/` 被整体忽略(既有规则),届时应加 `!.swiftpm/Package.resolved` 反豁免——记入风险,不在本次范围。
7. **保持 `.codex/`、`.zcode/` 跟踪(记录的假设)**:首次提交刻意纳入,视为共享的 AI 工作流配置;若后续希望本地化,可追加忽略,不影响本变更。

## Risks / Trade-offs

- [其他机器 pull 清理提交后,本地 `dist/` 变为未跟踪目录] → 文件不丢失(仅索引操作);提交说明中明确写出,便于协作者理解。
- [`text=auto` 对伪装成文本的二进制误判并转换行尾] → 已核实现存文本无 CRLF;png/icns 已显式 binary;若将来发现误判,对该扩展名追加 `-text` 豁免即可。
- [`.swiftpm/` 整体忽略导致未来 `Package.resolved` 无法入库] → 当前无依赖、无影响;引入依赖时按决策 6 反豁免。
- [`static_checks.py` 误扫新增文件] → 已确认它只扫描 `.swift`/`.json`/`.plist`,`.gitignore`/`.gitattributes` 不在范围,无需更新 checker。

## Migration Plan

单次清理提交:`.gitignore` 修改 + `.gitattributes` 新增 + `git rm -r --cached` dist;随后正常 push,CI 全量验证。回滚:`git revert` 该提交并恢复被移除的索引条目即可,无数据迁移。

## Open Questions

无 — 关键取舍均已落定。

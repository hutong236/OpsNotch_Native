# Tasks: setup-git-config

## 1. 忽略规则与属性约定

- [x] 1.1 在 `.gitignore` 追加规则(保留现有 5 条):`dist/`、`DerivedData/`、`*.dSYM`、`._*`、`.AppleDouble`、`.Spotlight-V100`、`.Trashes`、`.idea/`、`.vscode/`、`xcuserdata/`;验证:`git check-ignore -v "dist/x" "build/x" "DerivedData/x" "sub/.DS_Store"` 全部命中对应规则(`a.png` 不属于 ignore 范畴,由 1.2 的属性检查覆盖)
- [x] 1.2 新增根目录 `.gitattributes`:`* text=auto`、`*.sh text eol=lf`、`*.png binary`、`*.icns binary`;验证:`git check-attr text eol binary -- "*.sh" "*.png" "*.icns"` 输出 sh→text、png/icns→binary 且 eol 未设置(文本类)

## 2. 构建产物退出跟踪

- [x] 2.1 执行 `git rm -r --cached "dist"` 取消索引跟踪;验证:`git ls-files dist` 输出为空,且 `dist/Ops Notch.app/Contents/MacOS/OpsNotch` 仍存在于工作区
- [x] 2.2 确认不误伤既有跟踪:`git ls-files` 仍包含 `.codex/environments/environment.toml`、`.zcode/commands/opsx/propose.md`、`SOURCE_SHA256SUMS.txt`

## 3. 端到端验证与提交

- [x] 3.1 忽略生效验证:在 `dist/` 内创建临时文件后,`git status --porcelain -uall` 不出现该文件的未跟踪(`??`)条目且 `git check-ignore` 命中 `dist/` 规则,随后删除临时文件恢复现场
- [x] 3.2 项目基线不受影响:`swift build`、`swift test`、`python3 scripts/static_checks.py` 全部退出码为 0
- [x] 3.3 创建清理提交(提交说明写明 `dist/` 退出跟踪、协作者 pull 后本地目录保留为未跟踪状态);验证:提交后 `git status` 干净、`git log` 中首个提交 `312e753` 仍完好(历史未重写)

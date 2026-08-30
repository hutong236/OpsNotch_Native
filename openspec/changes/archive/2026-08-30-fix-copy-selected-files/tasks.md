# fix-copy-selected-files — 任务

## 1. Core 复制 payload 归类

- [x] 1.1 在 `Sources/OpsNotchCore/ShelfLogic.swift` 新增 `ShelfCopyPayload`(`filePaths: [String]`、`text: String?`)与 `ShelfLogic.copyPayload(items:)`:`.file/.folder/.application` 与 `.action(open_path)` 按条目顺序归入 `filePaths`,`.text/.url` 与 `.action(open_url)` 以 "\n" 连接归入 `text`;switch 覆盖全部 `ShelfKind`/`SafeActionKind` case 不用 default 兜底;移除 `ShelfLogic.copyText`。验证:`swift build` 通过且全仓 grep 无 `copyText` 残留引用
- [x] 1.2 在 `Tests/OpsNotchCoreTests/` 新增 `copyPayload` 用例:枚举全部 `ShelfKind`(action 覆盖两种 `actionKind`)的归类断言、多文件保序、混合选择的 text join 语义、空选择得空 payload。验证:`swift test` 中新增用例全绿

## 2. App 层写入与接入

- [x] 2.1 在 `Sources/OpsNotchApp/ClipboardManager.swift` 新增 `copyPayload(_ payload: ShelfCopyPayload)`:同一事务 `clearContents()` → `filePaths` 非空时 `writeObjects`(路径转 `NSURL`)→ `text` 非空时 `setString(_, forType: .string)` → 末尾同步 `handledChangeCount = pasteboard.changeCount`;既有 `copyFromApp` 保留给键盘 Enter/行内复制。验证:`swift build` 通过,审读确认基线同步位于写入之后
- [x] 2.2 改写 `Sources/OpsNotchApp/AppModel.swift` 的 `copySelected(using:)`:`ShelfLogic.copyPayload` 归类 → `guard !payload.isEmpty` 防御 → `clipboard.copyPayload(payload)` → 沿用 `copied` toast;不再有非空选择静默返回路径。验证:`swift build` 通过,选择条按钮触发路径走新方法

## 3. CI 同款校验

- [x] 3.1 运行 `swift build && swift test`,确认全绿(含既有 legacy 迁移用例未受影响)。验证:命令退出码 0
- [x] 3.2 运行 `python3 scripts/static_checks.py`,确认通过(`changeCount` 等必需 API 调用点未破坏)。验证:脚本退出码 0
- [x] 3.3 运行 `./scripts/build_app.sh` 确认可产出 .app(CI 同款)。验证:构建脚本退出码 0

## 4. GUI 实测(用户执行;应用须以打包 .app 运行,`swift run` 不能代表真实行为)

- [x] 4.1 执行 `./script/build_and_run.sh` 启动打包 .app,拖入多个文件(至少含 1 张图片),⌘点选后点击"复制所选",在 Finder ⌘V:应粘贴出全部所选文件(含图片文件本身),且界面出现"已复制"提示
- [x] 4.2 混合选择(文件 + 文字 + URL)点击"复制所选":Finder ⌘V 得全部文件;纯文本编辑器 ⌘V 得文字/URL 拼接文本;确认 Recent 无本次复制内容回灌
- [x] 4.3 回归确认:仅文字/URL 条目的"复制所选"与改动前一致;选中 action 条目复制后不再无反应(open_url 粘贴出 URL 文本,open_path 粘贴出文件引用)

## 1. 修复添加流程选择面板灰色不可选（AppModel.swift）

- [x] 1.1 `chooseFiles()`（约 :437-443）在 `runModal()` 前加入 `NSApplication.shared.activate(ignoringOtherApps: true)`；验证：`swift build` 通过
- [x] 1.2 `chooseFolder()`（约 :445-451）同上加入激活调用；验证：`swift build` 通过
- [x] 1.3 `chooseApplication()`（约 :453-461）加入激活调用，并把 `allowedContentTypes` 改为直接使用 `.application`（对齐 `InputMethodSettingsView.swift:130` 写法）；验证：`swift build` 通过

## 2. 修复编辑器 sheet 被 resignKey 收起（ShelfWindowController.swift）

- [x] 2.1 `didResignKey` 观察者（约 :71-81）补 `model.editorDraft == nil` 守卫，与 ：89 keyDown 监听、:220 `scheduleHide` 既有守卫同构；验证：`swift build` 通过

## 3. 回归与静态检查

- [x] 3.1 运行 `swift test`，确认既有 Core 测试（含 storage 迁移、ranking 等价测试）全部通过
- [x] 3.2 运行 `python3 scripts/static_checks.py`，确认 CI 门禁通过（本改动不触碰其要求的 API 调用点）
- [x] 3.3 确认与在途 shelf-performance 未提交改动无文件冲突（本改动仅触碰 `AppModel.swift` 的 choose* 区段与 `ShelfWindowController.swift`）

## 4. GUI 手动验收（留给用户实测，不代勾选）

- [x] 4.1 通过 `./script/build_and_run.sh` 打包启动；展开 shelf，点「+」→「添加应用…」：面板呈激活态、应用可选，确认后应用条目入 shelf
- [x] 4.2 点「+」→「添加安全操作…」：编辑器持续可见；输入名称与内容、切换「本地路径 / HTTP(S) URL」，保存后条目入 shelf；点取消可正常关闭
- [x] 4.3 回归：「+」→「添加文件…」「添加文件夹…」面板可选；「新建文字…」「添加网址…」编辑器可见；编辑器关闭后点击 shelf 外区域，shelf 仍按原行为自动隐藏

## 1. Core:~ 路径展开与校验

- [x] 1.1 `SafeActionValidator` 新增 `~`/`~/` 识别与 `expandedLocalPath` 归一化辅助(`~user/...` 拒绝,结果须 `/` 开头),并新增单元测试:`~/Documents`、`~` 展开成功,`~other/x`、相对路径返回 nil;运行 `swift test` 通过
- [x] 1.2 `ShelfStoreService.addAction` 与 `edit`(action 分支)落盘前先经 `expandedLocalPath` 归一化再校验;新增测试:`addAction(kind: .openPath, content: "~/Documents")` 落盘内容为展开后的绝对路径、`edit` 改为 `~/x` 同样展开;运行 `swift test` 通过

## 2. Core:安全操作筛选分类

- [x] 2.1 `ShelfKindFilter` 增加 `.action` case,`ShelfLogic.matchesKind` 改为六分类互斥(`.action` 仅匹配 `kind == .action`,从 `.file`/`.url` 分支移除 action 吸收);更新 `testKindFilterClassifiesAllKinds` 断言:openPath/openURL action 仅出现在 `.action` 筛选,并新增 `.action` 筛选断言;运行 `swift test` 通过
- [x] 2.2 确认 `SmartShelfRankingTests` 的 `ShelfKindFilter.allCases` 循环对新 case 无需修改即通过;运行 `swift test` 全绿

## 3. App:编辑器内联校验

- [x] 3.1 `ItemEditorView` 按 `draft.mode` + `draft.actionKind` 经 `SafeActionValidator` 实时计算有效性(新建文字非空、网址 isHTTPURL、安全操作按类型),无效时禁用保存按钮并在内容框下方就地显示原因;验证:无效输入下保存按钮禁用、提示可见
- [x] 3.2 `saveDraft` 保存失败路径不再无条件关闭编辑器(保持输入,toast 兜底保留);`Localization.swift` 新增 zh/en 内联原因文案与「安全操作 / Actions」筛选文案;验证:zh/en 两种语言文案均存在
- [x] 3.3 `ShelfView.filterChipsData` 追加 `(.action, L10n)` chip;`ShelfWindowController` ⌘1~⌘6 keyCode 数组追加 `22` 对应 `.action`;验证:`swift build` 通过,grep 确认 `registerForDraggedTypes([.fileURL, .URL, .string])` 等 static_checks 关键调用点未被改动

## 4. 回归与验收

- [x] 4.1 `swift build`、`swift test`、`python3 scripts/static_checks.py` 全部通过
- [x] 4.2 按 VERIFY_ON_MAC.md 方式打包实测(留给用户):添加 `~/...` 路径安全操作出现在清单、无效输入就地提示且不丢内容、「安全操作」chip 与 ⌘6 筛选生效、文件筛选下新增 action 条目自动回"全部"——完成后归档本变更

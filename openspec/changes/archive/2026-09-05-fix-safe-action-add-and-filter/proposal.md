## Why

用户通过「+」菜单「添加安全操作…」手工添加安全操作后,清单里不显示、`shelf.json` 中也从未出现 action 条目:保存被 `SafeActionValidator` 静默拒绝——openPath 只接受 `/` 开头的路径(最常见的 `~/...` 被拒),openURL 只接受带 http/https scheme 的完整 URL;而拒绝反馈仅是一条 1.25 秒即逝的 toast,编辑器却无条件关闭,输入内容丢失,用户完全不知道为什么没加上。同时类型筛选 chips(全部/文件/文本/URL/应用)没有「安全操作」分类,action 条目被吸收进文件/URL 筛选,用户无法专门查看自己的安全操作。

## What Changes

- 安全操作编辑器内联校验:按所选类型(本地路径 / HTTP/HTTPS URL)实时校验内容,无效时禁用保存按钮并就地显示原因;校验失败不再关闭编辑器,输入内容不丢失。
- openPath 类安全操作接受 `~` / `~/...` 输入,保存前展开为绝对路径落盘;安全边界不变——最终仍只允许展开后的本地绝对路径或 HTTP/HTTPS URL,`~user/...` 形式仍拒绝。
- 类型筛选新增「安全操作」分类:action 条目独占归入该分类,不再并入「文件」/「URL」筛选;键盘 ⌘1~⌘6 扩展到第六个筛选位。
- zh/en 文案新增「安全操作」筛选 chip 及编辑器内联错误提示。

记录的假设(无法从数据完全确证,修复覆盖全部失败形态):

- 用户输入的路径以 `~/` 开头(最常见形态)而被拒;用户 `shelf.json` 中无任何 action 条目支持"保存被拒"这一根因。
- 安全操作从「文件」/「URL」筛选中移出、独占「安全操作」分类(而非同时出现在三个分类),分类之间互斥更可预期。

## Capabilities

### New Capabilities

(无)

### Modified Capabilities

- `shelf-add-item-dialogs`: 新增要求——安全操作编辑器的内联校验与 `~` 路径展开:无效输入就地可见、编辑器不丢输入;openPath 接受并展开 `~` 形式路径。
- `shelf-kind-filter`: 修改「类型筛选 chips 与归类规则」与「键盘切换与高亮回落」——新增第六个「安全操作」筛选位,action 条目独占归入,⌘1~⌘6。

## Impact

- `Sources/OpsNotchCore/SafeActionValidator.swift` — 新增 `~` 识别与展开辅助。
- `Sources/OpsNotchCore/ShelfStoreService.swift` — `addAction` / `edit` 落盘前展开 `~` 路径。
- `Sources/OpsNotchCore/ShelfLogic.swift` — `ShelfKindFilter` 新增 `.action` case,`matchesKind` 归类规则调整。
- `Sources/OpsNotchApp/ShelfView.swift` — `ItemEditorView` 内联校验;`filterChipsData` 增加安全操作 chip。
- `Sources/OpsNotchApp/ShelfWindowController.swift` — 键盘 ⌘1~⌘6 筛选数组扩展。
- `Sources/OpsNotchApp/Localization.swift` — 新增 zh/en 文案。
- `Tests/OpsNotchCoreTests/` — 归类规则与 `~` 展开的单元测试更新/新增。
- 兼容性:`shelf.json` 格式不变(actionKind 已有存储),迁移逻辑不受影响;`static_checks.py` 要求的 API 调用点均不触及。

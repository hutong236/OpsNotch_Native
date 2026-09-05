## Context

手工添加安全操作的完整链路是:`ShelfView` 的「+」菜单置 `model.editorDraft = .action()` → `ItemEditorView`(sheet)→ `AppModel.saveDraft` → `AppModel.addSafeAction` → `ShelfStoreService.addAction`,后者用 `SafeActionValidator.validate` 把关:openPath 仅 `hasPrefix("/")`,openURL 仅 http/https。校验失败时只发一条 1.25 秒的 toast(`invalidAction`),而编辑器按钮无条件 `dismiss()`——这是"清单里没有显示"的直接路径(用户 `shelf.json` 中 action 条目数为 0)。

筛选链路:`ShelfKindFilter`(Core)五种筛选位;`ShelfLogic.matchesKind` 目前把 openPath 类 action 吸收进"文件"、openURL 类吸收进"URL";chips 在 `ShelfView.filterChipsData`,⌘1~⌘5 在 `ShelfWindowController` 的 keyCode 数组 `[18,19,20,21,23]`。

约束:Core 保持 Foundation-only、UI-free;`static_checks.py` 的 API 调用点不得破坏;安全边界(只开本地绝对路径 / http(s) URL,经 `SafeActionValidator.validate`)不可放松。

## Goals / Non-Goals

**Goals:**

- 手工添加安全操作的任何失败都在编辑器内即时可见,输入永不静默丢失。
- `~` / `~/` 形式路径开箱即用,落盘统一为展开后的绝对路径。
- 安全操作在类型筛选中有独立、互斥的分类,⌘1~⌘6 键盘流打通。

**Non-Goals:**

- 不改 toast 时长/样式机制(1.25s 是全局行为,另行处理)。
- 不给 URL 自动补 scheme、不接受 `file://` 或 `~user/...`(安全面与语义歧义,保持拒绝但提示可见)。
- 不改 `shelf.json` 格式、迁移逻辑与 `copyPayload` 等 ShelfKind 层语义。
- 不动 `ShelfSemantic` 的文本语义分类(`~/` 本就按 path 识别,与本变更无冲突)。

## Decisions

1. **校验前移到编辑器层,保存按钮禁用代替失败后提示。**
   `ItemEditorView` 内根据 `draft.mode` + `draft.actionKind` 调 `SafeActionValidator`(App→Core 已有依赖,方向合法)计算实时有效性:无效 → Save 禁用 + 内容框下方就地显示原因文案(zh/en 新增细分文案);有效才允许保存。相比"点击保存→失败→toast"的现有路径,这使失败态从编辑器外不可达,天然满足"不丢输入"。toast 保留为其他调用点的兜底。
   备选:保存时校验、失败不 dismiss——仍多一步无效点击,且错误出现更晚,弃。

2. **`~` 展开放在 Core,作为"归一化 + 再校验",而非放宽校验。**
   `SafeActionValidator` 新增 `expandedLocalPath(_:) -> String?`:仅 `~` 与 `~/...` 用 `NSString.expandingTildeInPath`(Foundation,Core 可用)展开并要求结果 `/` 开头;`~user/...` 返回 nil。`ShelfStoreService.addAction` 先展开再 `validate` 再落盘;`edit` 对 action 内容的再校验同样先展开。落盘内容恒为绝对路径,安全边界与现状等价(仍不可能存进相对路径或越权主目录)。
   备选:仅在 UI 层展开——`edit`、未来其他入口会漏;放 Core 一处收敛,弃。

3. **action 条目独占「安全操作」分类,从文件/URL 筛选中移出。**
   `ShelfKindFilter` 增加 `.action`;`matchesKind` 改为六分类互斥:`.action` 仅匹配 `kind == .action`,并从 `.file`/`.url` 分支删去 action 吸收。分类互斥比"一个条目出现在多个筛选"更可预期,也直接对应"过滤里没有安全操作的分类"的诉求。`AppModel.apply` 的"新增条目不受筛选隐藏"自动兜底:新增 action 条目不匹配当前 文件/URL 筛选时重置回"全部",不会出现"加了却被筛掉"。
   备选:保留文件/URL 吸收、新增并集 chip——chip 语义重叠,行为难解释,弃。

4. **chips 与键盘流同步扩一位。**
   `filterChipsData` 追加 `(.action, L10n "安全操作"/"Actions")`;`ShelfWindowController` keyCode 数组追加 `22`(数字 6)→ `⌘6 = 安全操作`。`ShelfKindFilter` 是 `CaseIterable`,`SmartShelfRankingTests` 的 `allCases` 循环自动覆盖新 case;`OpsNotchCoreTests.testKindFilterClassifiesAllKinds` 按新归类更新断言。

5. **文案细分校验原因。** 新增 zh/en:筛选「安全操作 / Actions」;编辑器内联提示区分"本地路径须为 `/` 或 `~` 开头的路径"与"仅支持 HTTP/HTTPS URL"(替代单一 `invalidAction` 文案;旧 key 保留给兜底 toast)。

## Risks / Trade-offs

- [改动 matchesKind 后,既有用户习惯"URL 筛选里看 openURL action"失效] → 属预期行为变更,spec 已明确;"全部"始终可见,新增条目自动重置筛选兜底。
- [`expandingTildeInPath` 对含 `~` 的普通目录名误展开] → 仅接受整串以 `~` 或 `~/` 开头,与 shell 惯例一致;展开结果必须 `/` 开头否则拒绝。
- [六枚 chips 在窄面板挤] → chip 字号 10pt、文案「安全操作」4 字,宽度实测余量足够;若不够,实现时缩短 en 文案为 `Actions`(已按此命名)。
- [测试断言大面积跟随调整] → 归类变化集中在 `testKindFilterClassifiesAllKinds`,一处收敛;`allCases` 循环无需手改。

## Migration Plan

无数据迁移:actionKind 已在 `shelf.json` 中持久化,存量 `~` 内容不存在(此前根本存不进去)。回滚即还原代码,无存储痕迹。

## Open Questions

无。

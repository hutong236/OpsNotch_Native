# fix-copy-selected-files — 设计

## Context

- 现状链路:选择条"复制所选"→ `AppModel.copySelected(using:)`(AppModel.swift:237)→ `ShelfLogic.copyText(items:)`(仅映射 `.text`/`.url`)→ `ClipboardManager.copyFromApp(_ text:)`(仅写 `.string`)。文件类条目在第一步即被丢弃,空串触发 `guard !text.isEmpty else { return }` 静默返回。
- 拖出链路(`NativeDragSourceView.makeDraggingItem`)已对 `.file/.folder/.application` 写 `NSURL` as `NSPasteboardWriter`,对 `.text/.action` 写 `NSString`——复制到剪贴板应与该语义对齐。
- 架构约束:归类逻辑须留在 Core(无 AppKit、可单测);剪贴板写入属 AppKit 层(ClipboardManager);应用自身写剪贴板后必须同步 `handledChangeCount` 基线(AGENTS.md gotcha)。
- 动机见 proposal.md,行为契约见 specs/shelf-selection-copy/spec.md。

## Goals / Non-Goals

**Goals:**
- "复制所选"对所有条目类型产出正确 payload:文件类(含图片文件)→ 文件 URL 多选写入,文字/URL → 文本,action 按 `actionKind` 归类。
- 混合选择单事务多 flavor 写入。
- 复制后基线同步,不回灌 Recent。
- 归类逻辑可 Core 单测覆盖。

**Non-Goals:**
- 不为图片文件额外写 TIFF/PNG 图像数据 flavor(保持 Finder"复制文件"语义,见决策 4)。
- 不新增单条目的文件复制入口(行内复制按钮/右键"复制"仍仅限 text/url,键盘 Enter 流不变)。
- 不改动拖出、传感器、存储格式与拖放注册类型。

## Decisions

1. **归类逻辑下沉 Core:新增 `ShelfLogic.copyPayload(items:) -> ShelfCopyPayload`,移除 `copyText`**
   - `ShelfCopyPayload`(Core 内 struct):`filePaths: [String]` + `text: String?`。`.file/.folder/.application` 与 `.action(open_path)` 归入 `filePaths`(按条目顺序);`.text/.url` 与 `.action(open_url)` 拼入 `text`("\n" 连接,沿用现 join 语义)。
   - 理由:归类规则是纯函数,放 Core 才能进 `Tests/OpsNotchCoreTests`(CI 可覆盖);放 ClipboardManager 则不可测且违反 Core 无 AppKit 的单向依赖。
   - 替代:保留 `copyText` 再加第二个函数——否,同一规则分居两处必然漂移;`copyText` 唯一调用方就是 `copySelected`,直接替换。

2. **写入放 ClipboardManager:新增 `copyPayload(_ payload: ShelfCopyPayload)` 单事务多 flavor**
   - `clearContents()` 一次;`filePaths` 非空 → `writeObjects(filePaths.map { URL(fileURLWithPath: $0) as NSURL })`;`text` 非空 → `setString(text, forType: .string)`;随后 `handledChangeCount = pasteboard.changeCount`。
   - 理由:与拖出同为 `NSURL`/`NSString` pasteboard writer,粘贴端拿到的 flavor 一致;基线同步与既有 `copyFromApp` 同法,满足"自身复制不回灌"。
   - 替代:手写 `NSFilenamesPboardType` 兼容旧类型——否,现代粘贴端(Finder/编辑器)均认 `NSPasteboardTypeFileURL`,先用最小 flavor 集,确有旧 app 兼容诉求再加。
   - 旧调用 `copyFromApp` 保留:键盘 Enter/行内复制等单文本路径仍走它。

3. **`copySelected` 改写,guard 仅作防御**
   - `let payload = ShelfLogic.copyPayload(items: selected)`;`guard !payload.isEmpty` 保留(理论上非空选择必非空,防未来新增 kind 未归类);`clipboard.copyPayload(payload)`;成功 toast 沿用 `copied` 文案。

4. **图片条目 = 文件 URL,不写图像数据**
   - 本项目图片条目即图片扩展名的文件条目(见 `ItemPreviewKind.imageExtensions`),不存在独立图像 kind。Finder"复制"图片文件也是写文件 URL;粘贴端(Finder、聊天、编辑器)自行从 fileURL 取内容。写 TIFF 需读盘解码、增大剪贴板负载且偏离"复制文件"语义。
   - 替代:对图片扩展名额外写 TIFF flavor 方便不支持 fileURL 的 app——记录为后续可选增强,不在本变更。

5. **复制不做存在性校验、不调 `SafeActionValidator`**
   - `SafeActionValidator` 守护"打开/执行"入口;复制只是数据搬运,不执行任何内容,粘贴端对纯文本/fileURL 无副作用。文件已删除仍按记录路径写入,与拖出一致、零 IO。

## Risks / Trade-offs

- [自身写入被 `catchIfChanged` 当作新剪贴板内容回灌] → `copyPayload` 内同步基线(与 `copyFromApp` 同法);写入与基线更新同在主线程同步完成,无竞态窗口。以既有用例模式补 Core 侧回归(基线逻辑在 App 层,Core 只测归类)。
- [混合 flavor 下粘贴端取到非预期 flavor] → flavor 集最小化:文件 URL 仅在文件子集非空时写、文本仅在文字子集非空时写,不写多余占位内容。
- [新 kind 未来加入 `ShelfKind` 未归类] → `copyPayload` 对未知 kind 返回空并在单元测试中枚举全部 `ShelfKind` case 断言归类,switch 不用 default 兜底,新 case 编译期即报错。

## Migration Plan

无存储/持久化变更,无迁移;回滚即还原本次代码改动。`copyText` 移除是内部 API 收窄,无外部调用方。

## Open Questions

无。

## Context

Shelf 面板是 `ShelfWindowController` 管理的一块 borderless `NSPanel`(level `.floating`,`canJoinAllSpaces`,`hidesOnDeactivate = false`),内容为 SwiftUI `ShelfView` 经 NSHostingView 承载。行内按钮与右键菜单都在 `ShelfView` 中定义;图片条目是普通 `.file` kind,仅显示系统文件图标。QuickLook 服务只接受 file/folder 且弹出的是系统 QLPreviewPanel。整体模式是"AppKit 管窗口与系统交互,SwiftUI 只管内容",本项目为 SPM 构建、macOS 13 起步、zh/en 运行时切换 L10n。

## Goals / Non-Goals

**Goals:**

- 一个独立于 Shelf 面板的置顶悬浮预览窗,文字/图片内容常驻显示,用户切换应用后仍可参照。
- 文字预览可读:大字号、换行、滚动、可选中复制、可调字号。
- 图片预览不开 Finder/Preview,在窗内直接渲染,支持缩放平移。
- 不改 `shelf.json` 格式,不做持久化,Core 保持 UI-free。

**Non-Goals:**

- 不支持多预览窗并存(单窗、内容替换,见 spec)。
- 不持久化预览窗位置/字号(会话内有效即可)。
- 不支持视频/PDF 等其他类型预览;不改变既有 QuickLook 与默认单击行为。
- 不引入新第三方依赖。

## Decisions

1. **新增 `FloatingPreviewController`(AppKit 单例)+ 独立 NSPanel**,与 `ShelfWindowController` 平行,不复用 Shelf 面板。
   - 理由:预览窗生命周期与 Shelf 展开态完全解耦(Shelf 自动隐藏时预览窗必须存活),复用面板会把两种互相冲突的隐藏逻辑搅在一起。与 QuickLook 方案(系统面板、无法定制字号/缩放、桌面弹出感)相比,自建面板才能满足 spec 的显示与交互要求。
2. **面板配置**:`NSPanel` + `.borderless` + `.nonactivatingPanelMask`,`canBecomeKey = true`(点击文字选区时面板成为 key 窗但不激活 App,键盘焦点留在用户原应用),`hidesOnDeactivate = false`,`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`,`level = .floating`(与 Shelf 一致,高于普通应用窗口)。显示用 `orderFrontRegardless()`,不调用 `makeKeyAndOrderFront` 以免抢焦点;关闭按钮用自绘小按钮(标题栏样式不适用于 borderless)。
3. **内容用 SwiftUI(NSHostingView)+ 少量 NSViewRepresentable**:
   - 文字:`NSScrollView + NSTextView` 包一层 `SelectableTextView`(NSViewRepresentable)——SwiftUI 的 `Text` 不可选中,`TextEditor` 样式难控制;NSTextView 天生支持选择、Cmd+C、滚动。
   - 图片:`Image` + `MagnificationGesture`/滚轮缩放 + `DragGesture` 平移,`scaleEffect` + `offset` 实现,"适配窗口"按钮重置状态。加载用 `NSImage(contentsOf:)` 放后台 Task,避免大图卡 UI。
   - 顶部工具条(标题、字号 +/−、"适配窗口"、关闭)用 SwiftUI,文案走 `L10n.text`。
4. **文字/图片判定进 Core**:在 `OpsNotchCore` 增加纯函数(如 `ShelfItemKind` 扩展/`isImagePath`),按扩展名集合(jpg/jpeg/png/gif/webp/heic/tiff/bmp/svg 等,大小写不敏感)判断 `.file` 条目是否为图片;放 Core 以便 XCTest 直接覆盖,且符合"Core 纯逻辑"约束。App 层据此决定放大入口是否显示及预览渲染分支。
5. **字号档位数组**(如 `[13, 16, 20, 26, 34, 44]`,默认 20)放在预览控制器内,+/− 在相邻档位间移动,到边界禁用;不落盘。
6. **预览窗出现位置**:首次出现在触发它的 Shelf 面板所在屏幕、notch 下方偏右;之后用户可拖动(borderless 面板需自己实现 `mouseDragged` 移动,借助 `isMovableByWindowBackground = true` 最简)。多屏场景不追踪 Shelf 迁移。

## Risks / Trade-offs

- [borderless 面板文字选中需要 key 窗状态] → `.nonactivatingPanelMask` + `canBecomeKey` 组合;验收时按 `VERIFY_ON_MAC.md` 手测焦点行为(CI 无法验证)。
- [巨型图片(数十 MP)内存占用] → 后台解码 + `NSImage` 按需绘制;`maxResizingBehavior` 交给 NSImage 自身,必要时后续限制最长边(不在本期)。
- [单窗内容替换导致用户误以为旧内容丢失] → 工具条标题显示条目标题,替换即视觉反馈;spec 已明确单窗语义。
- [`static_checks.py` 敏感词] → 新代码避免 "react"/"vite" 等子串(如注释里不写 "reactive"),不改动受保护的既有 API 调用点。
- [`swift run` 下预览窗行为与 .app 不完全一致] → 与登录项/传感器同一限制,验收以 `./script/build_and_run.sh` 打包为准。

## Migration Plan

纯新增 UI 能力,无数据迁移;回滚即删除新文件与 ShelfView 中的入口接线。

## Open Questions

无。

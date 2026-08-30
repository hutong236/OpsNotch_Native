## 1. Core:图片判定

- [x] 1.1 在 OpsNotchCore 新增图片扩展名判定纯函数(大小写不敏感,覆盖 jpg/jpeg/png/gif/webp/heic/tiff/bmp 等),并为它添加 XCTest 用例(图片扩展名返回 true、文件夹/文档/无扩展名返回 false);`swift test` 通过
- [x] 1.2 确认 Core 仍无 AppKit/SwiftUI 导入(`python3 scripts/static_checks.py` 与 `swift build` 通过)

## 2. 悬浮预览窗骨架

- [x] 2.1 新建 `Sources/OpsNotchApp/FloatingPreviewController.swift`:单例管理一个 borderless NSPanel,`.nonactivatingPanelMask`、`canBecomeKey`、`hidesOnDeactivate = false`、`canJoinAllSpaces`、`level = .floating`、`isMovableByWindowBackground = true`;提供 `show(item:)` / `close()`;`swift build` 通过
- [x] 2.2 实现窗口定位(触发 Shelf 面板所在屏幕、notch 下方)与工具条(条目标题 + 关闭按钮),关闭按钮可关闭窗口且不影响 Shelf 面板;手动检查:打开后切换其他应用,窗口保持置顶且不隐藏

## 3. 文字预览

- [x] 3.1 用 NSViewRepresentable 包 `NSScrollView + NSTextView` 实现可选中、可复制、自动换行、可滚动的文字内容区,大字号默认值;放大一条多行长文本,滚动可见全文、选中后 Cmd+C 可复制
- [x] 3.2 工具条加字号 +/− 控件,按档位数组在边界内调整字号并即时重排;到最大/最小档时按钮禁用;手动检查切换效果
- [x] 3.3 在 `Localization.swift` 的 zh/en 字典中补充预览相关文案(关闭、字号、适配窗口等),切换语言后文案跟随

## 4. 图片预览

- [x] 4.1 图片分支:后台 Task 加载 `NSImage`,在预览窗内按比例缩放适配显示,全程不调用 `NSWorkspace.open`/QuickLook;放大一张图片条目验证
- [x] 4.2 捏合/滚轮缩放 + 拖动平移,"适配窗口"按钮一键复位;手动检查缩放平移与复位
- [x] 4.3 验证复制模式(`shelf-files/`)与引用模式两种 storageMode 的图片路径都能正常显示

## 5. Shelf 入口接线

- [x] 5.1 `ShelfView.swift` 行内按钮区与右键菜单新增"放大预览"入口(仅文字与图片条目显示),点击调用 `FloatingPreviewController.show(item:)`;非文字/图片条目不可见;`swift build` 通过
- [x] 5.2 确认对图片条目使用既有 QuickLook eye 按钮与单击默认行为不变;Shelf 面板自动隐藏时预览窗仍置顶显示(`scheduleHide` 逻辑未被预览窗干扰)

## 6. 校验与验收

- [x] 6.1 `swift test`、`swift build`、`python3 scripts/static_checks.py`、`./scripts/build_app.sh` 全部通过
- [x] 6.2 按 `VERIFY_ON_MAC.md` 方式用 `./script/build_and_run.sh` 打包实测:置顶常驻、不抢键盘焦点(在其他应用输入时点击放大)、单窗替换、多屏下位置合理;发现问题回修

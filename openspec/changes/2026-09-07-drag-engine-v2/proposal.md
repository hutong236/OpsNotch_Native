# Proposal: Drag Engine V2 (v2.6.0)

## 背景

当前 Ops Notch 已具备顶部 Sensor、Drop 抽屉、Shelf、原生拖出、多显示器与 Smart Quick Shelf，但拖入入口仍以“用户把内容拖到顶部 Sensor”为前提。刘海屏虽然通过扩大 Sensor bounds 与安全区下方延伸带提升了命中率，用户仍然需要主动寻找入口，尤其在拖着文件跨窗口、跨 Space 或外接屏时不够自然。

参考 Yoink 的成熟交互，本变更不重写 Shelf，而是升级 Drag Lifecycle：从“固定目标等待用户命中”改为“检测到有效拖拽意图后，主动把 Drop Zone 放到用户附近”。

关联需求：GitHub Issue #47。

## 目标

将拖拽暂存升级为事件驱动、零额外权限优先的智能 Drag Engine：

`有效 Drag Session → 主动显示附近 Drop Zone → 原生 NSDraggingDestination 接收 → 解析真实内容/File Promise → 入 Shelf → 成功反馈/自动收起`

具体目标：

- 从 Finder、浏览器等其他 App 开始拖动受支持内容时，自动识别有效 Drag Session。
- 在当前鼠标所在屏显示明显、易命中的临时 Drop Zone，不要求用户寻找刘海小点。
- 顶部 Sensor 继续作为稳定兜底入口与 Ops Notch 品牌入口。
- 默认不新增 Accessibility / Input Monitoring 授权，不使用持续轮询。
- 支持 Finder 文件/文件夹、http/https URL、文字，并新增 NSFilePromiseReceiver 兼容 Safari/Photos 等来源。
- 拖拽取消、未落入、跨屏、显示器变化时正确收起/迁移，不残留悬浮窗口。
- 复用现有 ShelfStore、ShelfItem、Smart Quick Shelf、成功反馈与多屏策略。

## 非目标

- 不使用私有 API。
- 不执行 shell / SSH / kubectl / 任意命令。
- 不重写 Shelf 数据模型与 SmartScore。
- P0 不引入持久化 Stack/Group 数据结构。
- P0 不改变剪贴板历史捕获逻辑。
- P0 不要求拖出后自动删除 Shelf 条目；Finder-style 拖出语义与 Recall 在后续阶段完成。

## 兼容性

- Core/App 分层保持不变：系统拖拽检测、NSPanel、NSPasteboard、NSFilePromiseReceiver 全部留在 `OpsNotchApp`。
- `OpsNotchCore` 不引入 AppKit/SwiftUI。
- 保留 `SensorView.registerForDraggedTypes([.fileURL, .URL, .string])` 现有静态检查要求，并在其基础上追加 file promise readable types。
- 默认模式无新增持久化设置也能工作；后续用户偏好字段必须带默认值兼容旧 `shelf.json`。
- 不改变现有文件条目的真实 file URL 取回语义。

## 验收

以 GitHub Issue #47 与本变更下的 Specification 为准。建议目标发布版本为 `v2.6.0`。

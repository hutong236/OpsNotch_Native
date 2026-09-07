# Proposal: Drag Engine V2 (v2.6.0)

## 背景

当前 Ops Notch 已具备顶部 Sensor、Drop 抽屉、Shelf、原生拖出、多显示器与 Smart Quick Shelf，但拖入入口仍以“用户把内容拖到顶部 Sensor”为前提。刘海屏虽然通过扩大 Sensor bounds 与安全区下方延伸带提升了命中率，用户仍然需要主动寻找入口，尤其在拖着文件跨窗口、跨 Space 或外接屏时不够自然。

参考 Yoink 的成熟交互，本变更不重写 Shelf，而是升级 Drag Lifecycle：从“固定目标等待用户命中”改为“检测到有效拖拽意图后，主动把 Drop Zone 放到用户附近”。

关联需求：GitHub Issue #47。

## 本次需求目标

将拖拽暂存升级为事件驱动、零额外权限优先的智能 Drag Engine：

`有效 Drag Session → 主动显示附近 Drop Zone → 原生 NSDraggingDestination 接收 → 解析真实内容/File Promise → 入 Shelf → 成功反馈/自动收起`

具体目标：

- 从 Finder、浏览器等其他 App 开始拖动受支持内容时，自动识别有效 Drag Session。
- 在当前鼠标所在屏显示明显、易命中的临时 Drop Zone，不要求用户寻找刘海小点。
- 顶部 Sensor 继续作为稳定兜底入口与 Ops Notch 品牌入口。
- 默认不新增 Accessibility / Input Monitoring 授权，不使用持续轮询。
- 支持 Finder 文件/文件夹、http/https URL、文字，并兼容 Safari/Photos 等 `NSFilePromiseReceiver` 来源。
- 拖拽取消、未落入、跨屏时正确收起/迁移，不残留悬浮窗口。
- 复用现有 ShelfStore、ShelfItem、Smart Quick Shelf、成功反馈与多屏策略。

## 完成边界

本需求以“解决拖入入口难找和外部拖入可靠性”为完成标准。已经随实现合并的 Drag-out/Recall、Sensor-only 和可访问性增强保留，但不继续向外扩展产品范围。

## 明确非目标

- 不使用私有 API。
- 不执行 shell / SSH / kubectl / 任意命令。
- 不重写 Shelf 数据模型与 SmartScore。
- 不开发 ignored-app/source-app 排除列表。
- 不开发多文件 Stack/grouping 或新的持久化 Stack 数据模型。
- 不为了架构整洁继续拆分 payload priority/state machine，只要当前实现满足功能与 CI 即停止扩展。
- 不新增独立 `locked` 持久化模型。
- 不把 Finder 修饰键行为扩展为新的文件移动功能；文件语义以安全、不破坏原路径为准。

## 兼容性

- Core/App 分层保持不变：系统拖拽检测、NSPanel、NSPasteboard、NSFilePromiseReceiver 全部留在 `OpsNotchApp`。
- `OpsNotchCore` 不引入 AppKit/SwiftUI。
- 保留 `SensorView.registerForDraggedTypes([.fileURL, .URL, .string])` 现有静态检查要求，并在其基础上追加 File Promise readable types。
- `drag_assist_mode` 缺失时自动回落 Nearby，兼容旧 `shelf.json`。
- 不改变现有文件条目的真实 file URL 取回语义。

## 验收

代码完成以 Issue #47 核心目标、Specification 与现有 CI 为准；真机 Finder/Safari/Photos/多屏检查作为 v2.6.0 发布前 smoke test，不扩展为新的开发功能。

# Tasks: Drag Engine V2

## Phase 1 — P0 Drag Intent + Nearby Drop Zone

- [x] 1.1 新增 `DragSessionCoordinator.swift`，统一管理外部拖入状态。
- [x] 1.2 用 `NSEvent.addGlobalMonitorForEvents` 监听外部 mouse-drag/mouse-up；deinit/stop 时可靠移除 monitor。
- [x] 1.3 使用 `NSPasteboard(name: .drag).changeCount` + supported types 区分真实可接收拖放与普通窗口/滑块拖动。
- [x] 1.4 不使用 Timer 做 drag detection；pasteboard 首帧未就绪时依赖后续 mouseDragged 事件重试。
- [x] 1.5 新增 `DragDropOverlayController.swift`：borderless、nonactivating、不可成为 key、支持 all Spaces/full-screen auxiliary。
- [x] 1.6 新增 AppKit `NearbyDropView`，注册与 Sensor 一致的基础拖放类型并实现 `NSDraggingDestination`。
- [x] 1.7 Overlay 初始位置基于 `NSEvent.mouseLocation`，按当前 `NSScreen.visibleFrame` clamp，并实现边缘自动翻转。
- [x] 1.8 拖拽跨显示器时迁移唯一 Overlay；禁止多屏重复出现活动 target。
- [x] 1.9 通过现有 `ShelfWindowController.onVisibilityChange` 将 Sensor/Shelf 接管状态接入 coordinator；顶部 Sensor 出现时 nearby overlay 自动让位，保持 `SensorManager` 原拖放链路不变。
- [ ] 1.10 进一步将 `ShelfWindowController` 的 drop/success/hide 调度完全收敛到统一 drag state；Phase 1 当前采用可见性事件协调，避免侵入既有 Shelf 生命周期。
- [ ] 1.11 拖拽取消、mouseUp、跨屏已回到 idle；显示器热拔插/系统异常终止仍需真机验收后确认。
- [x] 1.12 保证 Drag Assist 失败/关闭时现有顶部 Sensor 行为完全可用；Phase 1 未修改 Sensor 原接收实现。
- [x] 1.13 Nearby Drop Zone 复用现有中英文 `dropTitle` / `dropHint` 文案，不新增重复字符串。
- [ ] 1.14 当前日志仅记录 drag assist display 与 payload 类型/数量且不记录正文；session/state 完整结构化日志后续补齐。

## Phase 2 — P0/P1 File Promise 与 Payload Resolver

- [ ] 2.1 新增 `DropPayloadResolver.swift`，Sensor 与 Overlay 统一调用。
- [ ] 2.2 保留静态检查要求的 `registerForDraggedTypes([.fileURL, .URL, .string])`，并追加 `NSFilePromiseReceiver.readableDraggedTypes`。
- [ ] 2.3 解析优先级固定为 File Promise → fileURL → http/https URL → string。
- [ ] 2.4 将当前同步 `NativeDropPayload.read` 拆为轻量可接收判定与真正 drop resolution。
- [ ] 2.5 创建 session-scoped staging 目录接收 promises。
- [ ] 2.6 使用 `NSFilePromiseReceiver.receivePromisedFiles` 异步接收并汇总完成结果。
- [ ] 2.7 Promise 全成功：一次性 ingest；部分成功：只 ingest 成功项；全部失败：不创建 ShelfItem。
- [ ] 2.8 Promise session 完成/失败/取消后清理不再需要的 staging 资源。
- [ ] 2.9 大文件 promise 期间显示 `resolvingPromise` 反馈，禁止 UI 卡在 Drop 状态。
- [ ] 2.10 Safari/Chrome/Photos/File Promise 与 Finder file URL 做真机回归。

## Phase 3 — P1 Native Drag-out Semantics

- [ ] 3.1 审核 `NativeDragSourceView` 当前固定 `.copy` 行为，改为允许 AppKit 协商安全的 copy/move operation。
- [ ] 3.2 实现 `draggingSession(_:endedAt:operation:)`，只在最终 operation 成功时触发 Shelf 后处理。
- [ ] 3.3 普通临时条目支持“成功拖出后移除”；取消/失败绝不移除。
- [ ] 3.4 pinned/locked 条目成功拖出后继续保留。
- [ ] 3.5 增加最近移除项 Recall/Undo 队列，至少支持恢复最后一次 drag-out 移除。
- [ ] 3.6 回归 Issue #46：重复复制后 pin/unpin 状态必须正确。
- [ ] 3.7 验证 Option/Command 修饰键与 Finder 目标下的最终 operation，不自行伪造文件移动。

## Phase 4 — P2 精细化

- [ ] 4.1 增加 `dragAssistMode`：默认 nearby，可选 sensor-only；若持久化则提供 Codable 默认值与 migration test。
- [ ] 4.2 评估 ignored app bundle IDs；仅在 source app 可可靠识别时实现。
- [ ] 4.3 多文件一次拖入增加 UI-level session grouping/Stack 方案，避免立即修改持久化模型。
- [ ] 4.4 为 Drag Assist 增加 Reduce Motion 与可访问性细节。

## 自动化验证

- [x] A1 `swift test`（PR #48 CI run 81 通过）
- [x] A2 `swift build`（PR #48 CI run 81 Debug build 通过）
- [x] A3 `python3 scripts/static_checks.py`（PR #48 CI run 81 Architecture checks 通过）
- [x] A4 Phase 1 未新增 Core/Settings 持久化字段，无 migration 变更需要验证。
- [ ] A5 为可抽离的 drag state transition/payload type priority 添加单元测试。

## 真机验收

- [ ] M1 刘海 MacBook：Finder 单文件、多文件、文件夹拖入；无需寻找顶部小点即可看到 nearby Drop Zone。
- [ ] M2 普通无刘海屏：Drop Zone 位置正确且不遮挡菜单栏/Dock。
- [ ] M3 外接双屏：Drag 从屏 A 移到屏 B，target 跟随且只有一个。
- [ ] M4 拖拽过程中拔掉外接屏，不崩溃、不残留窗口、不破坏系统原始 drag。
- [ ] M5 Safari/Chrome：URL、选中文字、网页图片。
- [ ] M6 Photos：单图、多图、大图 File Promise。
- [ ] M7 拖拽开始后取消/未 Drop，UI 自动消失且 Shelf 不新增数据。
- [ ] M8 Drop 到 Sensor 与 Drop 到 nearby Overlay 都只入柜一次。
- [ ] M9 Spaces/full-screen App 下可见且不抢焦点。
- [ ] M10 Reduce Motion 打开时无明显位移动画问题。
- [ ] M11 默认升级/首次运行不主动弹 Accessibility/Input Monitoring 权限。
- [ ] M12 `./script/build_and_run.sh --logs` 检查日志不包含文件完整路径、URL 正文、文字正文。

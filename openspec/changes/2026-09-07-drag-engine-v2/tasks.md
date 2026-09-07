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
- [x] 1.9 通过现有 `ShelfWindowController.onVisibilityChange` 将 Sensor/Shelf 接管状态接入 coordinator；顶部 Sensor 出现时 nearby overlay 自动让位。
- [ ] 1.10 进一步将 `ShelfWindowController` 的 drop/success/hide 调度完全收敛到统一 drag state；当前采用可见性事件协调，避免侵入既有 Shelf 生命周期。
- [ ] 1.11 拖拽取消、mouseUp、跨屏已回到 idle；显示器热拔插/系统异常终止仍需真机验收后确认。
- [x] 1.12 保证 Drag Assist 失败/关闭时现有顶部 Sensor 行为完全可用；Phase 2 仅扩展其 payload resolver，不移除原基础拖放能力。
- [x] 1.13 Nearby Drop Zone 复用现有中英文 `dropTitle` / `dropHint` 文案，不新增重复字符串。
- [ ] 1.14 当前日志仅记录 drag assist display、payload 类型/数量与 promise 成败计数且不记录正文；session/state 完整结构化日志后续补齐。

## Phase 2 — P0/P1 File Promise 与 Payload Resolver

- [x] 2.1 新增 `DropPayloadResolver.swift`；Nearby Drop Zone、顶部 Sensor、展开 Shelf 三个接收点均统一调用。
- [x] 2.2 保留静态检查要求的 `registerForDraggedTypes([.fileURL, .URL, .string])`，并追加 `NSFilePromiseReceiver.readableDraggedTypes`。
- [x] 2.3 解析优先级固定为 File Promise → fileURL → http/https URL → string。
- [ ] 2.4 Resolver 已统一负责类型判定、Promise 优先级与异步 resolution，但 `NativeDropPayload.read` 仍保留为 immediate payload decoder；后续再进一步拆分职责。
- [x] 2.5 创建 session-scoped `drop-staging/<UUID>` 目录接收 promises。
- [x] 2.6 使用 `NSFilePromiseReceiver.receivePromisedFiles` + 独立 `OperationQueue` 异步接收并在全部 reader 工作完成后汇总。
- [x] 2.7 Promise 完成后按成功 URL 批量交给统一 ingest；部分成功只入柜成功项；全部失败不创建 ShelfItem。
- [x] 2.8 正常 Promise 完成/失败后清理 session staging；异常退出遗留的 `drop-staging` 在下一次应用启动、任何新 drag session 建立前统一安全清理。
- [ ] 2.9 Nearby Drop Zone 已提供 `resolvingPromise` spinner，Sensor/Shelf 有接收反馈；超大文件最终复制仍需真机性能验证，暂不标记完成。
- [ ] 2.10 Safari/Chrome/Photos/File Promise 与 Finder file URL 做真机回归。

## Phase 3 — P1 Native Drag-out Semantics

- [x] 3.1 审核并替换 `NativeDragSourceView` 固定 `.copy`：path-backed 文件/目录/应用保持安全 copy-only，纯文本/URL/action 允许 AppKit 协商 copy/move。
- [x] 3.2 实现 `draggingSession(_:endedAt:operation:)`，只以 AppKit 最终 operation 触发 Shelf 后处理；内部 drop-back 禁止接收。
- [x] 3.3 普通临时条目支持“成功拖出后移除”；取消/失败绝不移除。
- [ ] 3.4 pinned 与 Working Set 条目成功拖出后已保留；项目当前没有独立 `locked` 持久化字段，因此 locked 语义尚未实现。
- [x] 3.5 增加单步 Recall/Undo：`⌘Z` 恢复最近一次 drag-out 移除；`storageMode=.copy` 受管目录进入 recall stash，可随条目一起恢复；启动时可恢复崩溃中间态并清理真正陈旧 stash。
- [ ] 3.6 回归 Issue #46：重复复制后 pin/unpin 状态必须正确。
- [ ] 3.7 验证 Option/Command 修饰键与 Finder 目标下的最终 operation，不自行伪造文件移动。

## Phase 4 — P2 精细化

- [x] 4.1 增加 `dragAssistMode`：默认 nearby，可选 sensor-only；持久化为 `drag_assist_mode`，旧配置缺字段时 Codable 自动回落 nearby，并有兼容/round-trip Core tests。
- [ ] 4.2 评估 ignored app bundle IDs；仅在 source app 可可靠识别时实现。
- [ ] 4.3 多文件一次拖入增加 UI-level session grouping/Stack 方案，避免立即修改持久化模型。
- [x] 4.4 Drag Assist 遵循 macOS Reduce Motion；Nearby Drop Zone 暴露 VoiceOver group/label/help，File Promise resolving 状态同步更新可访问性文本。

## 自动化验证

- [x] A1 `swift test`（PR #52 CI run 95 通过）。
- [x] A2 `swift build`（PR #52 CI run 95 Debug build 通过）。
- [x] A3 `python3 scripts/static_checks.py`（PR #52 CI run 95 Architecture checks 通过）。
- [x] A4 Phase 4 新增 `drag_assist_mode` 持久化字段；`ShelfSettingsCompatibilityTests` 验证默认 nearby、旧 JSON 缺字段兼容和 sensor-only Codable round-trip，无破坏性 migration/version bump。
- [ ] A5 为可抽离的 drag state transition/payload type priority 添加单元测试。

## 真机验收

- [ ] M1 刘海 MacBook：Finder 单文件、多文件、文件夹拖入；无需寻找顶部小点即可看到 nearby Drop Zone。
- [ ] M2 普通无刘海屏：Drop Zone 位置正确且不遮挡菜单栏/Dock。
- [ ] M3 外接双屏：Drag 从屏 A 移到屏 B，target 跟随且只有一个。
- [ ] M4 拖拽过程中拔掉外接屏，不崩溃、不残留窗口、不破坏系统原始 drag。
- [ ] M5 Safari/Chrome：URL、选中文字、网页图片。
- [ ] M6 Photos：单图、多图、大图 File Promise。
- [ ] M7 拖拽开始后取消/未 Drop，UI 自动消失且 Shelf 不新增数据。
- [ ] M8 Drop 到 Sensor、nearby Overlay 与展开 Shelf 都只入柜一次。
- [ ] M9 Spaces/full-screen App 下可见且不抢焦点。
- [ ] M10 Reduce Motion 打开时无明显位移动画问题。
- [ ] M11 默认升级/首次运行不主动弹 Accessibility/Input Monitoring 权限。
- [ ] M12 `./script/build_and_run.sh --logs` 检查日志不包含文件完整路径、URL 正文、文字正文。
- [ ] M13 Finder 成功拖出普通条目后 Shelf 移除；拖拽取消/失败不移除；Pinned/Working Set 条目保持。
- [ ] M14 `storageMode=.copy` 文件成功拖出后按 `⌘Z`，受管文件与 ShelfItem 均恢复且可继续打开/Quick Look。
- [ ] M15 Finder 下验证 Option/Command 修饰键和最终 operation；path-backed 条目不得导致原文件被 Ops Notch 主动移动。
- [ ] M16 模拟 drag-out consume 中断后重启，仍被持久化 Shelf 引用的受管文件从 recall stash 自动恢复，不发生数据丢失。
- [ ] M17 设置 Drag Assist=Sensor only 后，外部拖拽不出现 Nearby Overlay，但顶部 Sensor 仍可接收 Finder/File Promise；切回 Nearby 后恢复默认行为。
- [ ] M18 VoiceOver 开启时 Nearby Drop Zone 能读出“松开即可放入/Release to add”及提示；File Promise 接收中能读出 resolving 状态。
- [ ] M19 人工制造旧 `drop-staging/<UUID>` 后重启应用，启动清理会删除残留且不影响现有 ShelfItem。

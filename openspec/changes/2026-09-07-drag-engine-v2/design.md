# Design: Drag Engine V2

## 1. 设计原则

1. **增量改造，不重写 Shelf。** 现有 `SensorManager`、`ShelfWindowController`、`NativeDragSourceView`、ShelfStore 与 Smart Quick Shelf 继续复用。
2. **AppKit 管系统拖拽。** 全局拖拽意图识别、NSPanel、NSDraggingDestination、NSPasteboard、NSFilePromiseReceiver 全部位于 `OpsNotchApp`。
3. **事件驱动，不轮询。** 仅在 mouse-drag / mouse-up / NSDraggingDestination 回调发生时检查 drag pasteboard。
4. **零额外权限优先。** 默认路径不得主动触发 Accessibility / Input Monitoring 授权。
5. **Pasteboard 只负责判断与接收，不提前读取大内容。** 拖拽识别阶段优先读 `changeCount` / `types`，真正进入 Ops Notch Drop Destination 后再解析 payload。
6. **单一状态机管理窗口。** 避免 Sensor、鼠标附近 Overlay、Shelf Drop、Success 各自调 show/hide 造成竞态。
7. **失败可回退。** 如果全局 Drag Intent 未识别，现有顶部 Sensor 仍能完成所有当前拖入操作。

## 2. 当前结构与问题

当前链路：

```text
Source App
   ↓
用户主动拖到顶部 Sensor
   ↓
SensorView.draggingEntered
   ↓
ShelfWindowController.showDrop
   ↓
performDragOperation
   ↓
NativeDropPayload
   ↓
Shelf
```

现有实现已经解决“Drop 面板本身也可接收拖放”和“刘海安全区下方增加可命中带”，但核心交互仍是：

```text
用户拖东西 → 用户寻找顶部目标 → 命中 Sensor → Ops Notch 才出现
```

V2 改为：

```text
用户拖东西
   ↓
DragSessionCoordinator 识别有效 drag pasteboard
   ↓
当前鼠标附近主动出现 Drop Zone
   ↓
用户小幅移动即可进入原生 NSDraggingDestination
   ↓
DropPayloadResolver
   ↓
Shelf
```

## 3. DragSessionCoordinator

新增 `Sources/OpsNotchApp/DragSessionCoordinator.swift`，`@MainActor` 管理整个外部拖入生命周期。

### 3.1 检测来源

使用：

- `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .rightMouseDragged, .otherMouseDragged])`
- 对应 mouse-up monitor 作为外部取消/结束兜底。
- `NSPasteboard(name: .drag)` 的 `changeCount` 与 `types`。

判断策略：

```text
收到 mouseDragged
   ↓
当前 session 是否已 recognized？——是→只更新鼠标/屏幕位置
   ↓ 否
.drag.changeCount 是否相对 baseline 变化？——否→忽略（窗口移动/普通拖鼠标等）
   ↓ 是
是否包含 Ops Notch 支持的拖放类型？——否→记录 baseline 后忽略
   ↓ 是
进入 recognized
```

注意 drag pasteboard 与第一帧 mouseDragged 可能存在时序差，因此在尚未 recognized 的同一次鼠标拖动期间，每个后续 mouseDragged 事件都允许再次检查；这仍然是事件驱动，不是 Timer polling。

### 3.2 支持类型的“轻判断”

识别阶段只检查类型，不提前解析 URL/文件内容：

- `NSFilePromiseReceiver.readableDraggedTypes`
- `.fileURL`
- `.URL`
- `.string`

真正内容解析延迟到 `NSDraggingInfo.draggingPasteboard` 进入本应用窗口以后。

### 3.3 自身拖出

Apple 的 global monitor 不接收发送给本应用自身的事件，因此从 Ops Notch 自己拖条目出去不会被 Drag Engine 当成新的外部拖入会话；`NativeDragSourceView` 保持独立生命周期。

## 4. Drag Session 状态机

建议状态：

```swift
enum DragAssistState: Equatable {
    case idle
    case trackingExternalDrag(changeCount: Int, displayID: CGDirectDisplayID)
    case targetVisible(displayID: CGDirectDisplayID)
    case receiving(displayID: CGDirectDisplayID)
    case resolvingPromise(displayID: CGDirectDisplayID)
    case succeeded(displayID: CGDirectDisplayID)
    case cancelling
}
```

状态转换：

```text
idle
 └─ valid external drag ─────────────→ trackingExternalDrag
                                         │
                                         └─ show overlay → targetVisible
                                                              │
                         draggingEntered ──────────────────────┤
                                                              ▼
                                                         receiving
                                                          │      │
                                       ordinary payload ──┘      └─ file promise
                                                          │             │
                                                          ▼             ▼
                                                      succeeded   resolvingPromise
                                                                        │
                                                                        ▼
                                                                   succeeded

任意未成功状态 ─ mouseUp / cancel / drag ended ─→ cancelling ─→ idle
succeeded ─ success feedback timeout ─────────────→ idle
```

所有 Overlay/Shelf show-hide 都通过 coordinator 发出，避免多个 controller 各自调度隐藏。

## 5. DragDropOverlayController

新增 `Sources/OpsNotchApp/DragDropOverlayController.swift`。

### 5.1 窗口

- `NSPanel`
- `.borderless + .nonactivatingPanel`
- `canBecomeKey = false`
- 不调用 `makeKey`，不夺走原 App 焦点。
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
- 仅 Drag Session 有效期间 `orderFrontRegardless()`。
- 内容 View 使用 AppKit `NSDraggingDestination`，不使用 SwiftUI gesture 模拟。

### 5.2 初始位置

默认使用“鼠标附近但不挡住拖拽预览”的偏移位置，例如：

```text
cursor
  ●──── 28~40 pt ────┐
                     │  Drop Zone
                     └────────────
```

定位规则：

1. 找 `NSEvent.mouseLocation` 所在 `NSScreen`。
2. 目标 frame 使用当前 screen `visibleFrame` 做 clamp。
3. 若靠右/靠下无空间，自动翻转到左侧/上侧。
4. 跨屏后仅迁移同一个 Overlay，不同时在多屏制造多个浮层。
5. Reduced Motion 开启时关闭位移动画。

### 5.3 视觉层级

P0 保持极简：

- 文件托盘/向下箭头图标。
- “放到这里暂存” / `Drop to Shelf`。
- 多文件可显示系统拖拽数量，不做持久化 Stack。
- 当 cursor 真正进入 Drop Zone 时放大 8~12%，突出 ready 状态。

Overlay 仅服务当前 Drag Session，平时完全不存在视觉干扰。

## 6. Sensor 与 Overlay 的关系

顶部 Sensor 不删除，职责调整：

- **Sensor**：固定品牌入口、普通 hover 唤醒、稳定原生 Drop fallback。
- **Nearby Overlay**：有效外部拖拽时的主动目标。
- **Shelf Drop Panel**：用户拖到顶部 Sensor 后的展开反馈，继续复用。

优先级：

```text
Drag start → Nearby Overlay
     │
     ├─ 用户直接放 Overlay → Shelf
     │
     └─ 用户继续拖到顶部 Sensor → 隐藏 Overlay + showDrop(on: screen) → Shelf
```

Sensor `draggingEntered` 时 coordinator 将状态切到 receiving，并隐藏附近 Overlay，避免两个目标同时抢视觉注意力。

## 7. DropPayloadResolver

新增 `Sources/OpsNotchApp/DropPayloadResolver.swift`，将 `NativeDropPayload` 的读取逻辑从 `SensorManager` 解耦出来，Sensor 与 Overlay 共用。

### 7.1 解析优先级

必须优先 File Promise：

1. `NSFilePromiseReceiver`
2. file URL(s)
3. http/https URL
4. string

原因：Safari/Photos 等来源可能同时提供低质量/间接表示与 file promise；promise 往往是正确的真实文件结果。

### 7.2 File Promise

`NSFilePromiseReceiver.receivePromisedFiles(...)` 是异步过程，因此当前同步 `dropHandler: (NativeDropPayload) -> Bool` 不能承担完整 promise 生命周期。

建议引入：

```swift
enum DropResolution {
    case immediate(NativeDropPayload)
    case promised([NSFilePromiseReceiver])
}
```

Promise 目标目录使用应用管理的接收 staging 目录，例如：

```text
~/Library/Application Support/lab.hutong.opsnotch/drop-staging/<session-uuid>/
```

全部 promise 完成后再统一调用现有 `model.addPaths(...)`。失败条目不制造空 ShelfItem；部分成功时只添加成功文件，并给诊断日志记录成功/失败数量。

完成后是否移动到现有 `shelf-files/` 继续由当前 ShelfStore 规则决定，resolver 不复制 Core 的持久化职责。

## 8. 多屏与 Spaces

复用现有 displayID 计算和 `didChangeScreenParametersNotification`。

规则：

- Drag target 永远跟随当前鼠标所在屏，而不是 `NSScreen.main`。
- 外接屏拔出时若当前 overlay 在被移除屏，立即迁移到新的 mouse screen；无法解析时取消 assist，但不影响系统原始 drag。
- Overlay 与 Sensor 都使用 `.canJoinAllSpaces` / `.fullScreenAuxiliary`。
- 不通过切换 active app / key window 来显示 Drop Zone。

## 9. 拖出语义（Phase 3）

当前 `NativeDragSourceView` 的 source operation 固定 `.copy`。后续升级目标：

- source operation mask 允许系统根据目标与修饰键协商 copy/move。
- `Option` 强制 Copy、`Command` 强制 Move 的体验尽量遵循 Finder。
- 在 `draggingSession(_:endedAt:operation:)` 里只在明确成功 operation 后执行 Shelf 的“用后处理”。
- Pinned/Locked 条目拖出后保留；普通临时条目可按设置移除。
- 增加短期 Recall/Undo 队列，避免误移除。

该阶段必须与当前 pin 语义和 Issue #46 的反置顶修复做回归测试，P0 不改变此行为。

## 10. Ignore Apps（Phase 4）

对设计/游戏等大量内部 drag 行为的 App 可提供忽略列表：

- 只存 bundle id，不保存前台 App 历史。
- 当前 source app 若无法可靠获取，则该能力仅作为后续增强，不阻塞 P0。
- 手动顶部 Sensor 入口仍可使用。

## 11. 诊断与隐私

现有 `dropLog` 继续使用，但只记录：

- state transition
- displayID
- pasteboard type category
- file count / promise count
- resolve duration
- success/failure count

禁止记录：

- 文件完整路径
- URL 正文
- 拖入文字正文

## 12. 失败与回退策略

- 全局 monitor 创建失败：Nearby Overlay 不启用，顶部 Sensor 完整可用。
- drag pasteboard 尚未更新：等待下一次 mouseDragged 事件再次判断，不启 Timer。
- promise 失败：清理 session staging，保留成功项；全部失败则显示失败反馈并收起。
- Overlay 未进入 destination 就 mouseUp：立即隐藏，不产生 Shelf 数据。
- Overlay 被窗口系统拒绝显示：不影响原生 drag，会话退回 Sensor-only。

## 13. 建议实现顺序

### Phase 1 — P0 Drag Intent + Nearby Drop Zone

- DragSessionCoordinator
- DragDropOverlayController
- 当前 payload 类型复用
- Sensor/Overlay 状态统一
- 多屏/取消/焦点回归

### Phase 2 — P0/P1 File Promise

- DropPayloadResolver
- NSFilePromiseReceiver
- staging 生命周期
- Safari/Photos/Browser 回归

### Phase 3 — P1 Finder-style Drag Out

- operation negotiation
- 普通条目用后移除
- pinned 保留
- Recall/Undo

### Phase 4 — P2 精细化

- ignored apps
- 多文件 session grouping / Stack UI
- 用户可选 `nearby / sensor-only` 拖拽辅助模式

## 14. 测试边界

CI 可覆盖：

- Drag assist 纯状态机 reducer/transition（建议抽成 Core-free pure struct 或 App 内可测试 helper）。
- payload 类型优先级的纯判断部分。
- setting migration（若 Phase 4 新增字段）。

必须真机手工验收：

- 刘海 MacBook。
- 无刘海屏。
- 单外接屏/双屏。
- Spaces 与全屏 App。
- Finder 单文件、多文件、文件夹、App。
- Safari/Chrome 链接、文字、网页图片。
- Photos 大图/多图 File Promise。
- 拖入后取消、跨屏、拔屏、Esc。
- Reduce Motion。

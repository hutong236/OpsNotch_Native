# Proposal: Shelf 常驻展开 + 触发区半透明指示点 (2026-09-05-shelf-pin-and-sensor-dot)

## Why

当前 Shelf 完全不可见：传感器是一个透明命中区，收起后用户（尤其新用户）不知道刘海/顶部哪里可以悬停，入口可发现性差。同时 Shelf 只有"移入展开、移开约 0.5s 自动隐藏"一种行为，用户在长时间连续取放物品（如运维操作时反复拖文件、看 IP/命令）时会被自动隐藏打断，缺少"钉住常开"的工作模式。

## What Changes

- 新增"常驻展开"（图钉）模式：
  - Shelf UI 内提供一个图钉开关（与条目级 pinned 在视觉与语义上区分），开启后 Shelf 持续展开、所有自动隐藏路径失效（鼠标移出、Shelf 内移出、拖放 peek 延迟、失 key、确认后的延迟隐藏）。
  - 显式动作仍可隐藏：Esc（临时收起，图钉状态保留）、再次点击图钉取消常驻（收起）。
  - 常驻状态持久化（新增 `ShelfSettings` 带默认值的 Bool 字段），重启后仍生效；启动时若开启则直接展开。
  - 设置窗口增加镜像开关，方便发现与关闭。
- 触发区新增半透明指示点：仅当 Shelf 完全收起时，在传感器区域绘制一个小尺寸半透明圆点提示入口位置；Shelf 展开/拖放/peek 期间不显示；通过事件回调更新，不引入轮询。
- 本地化：新增 UI 文案同时进入 zh/en 两套词典。

## Capabilities

### New Capabilities

- `shelf-pin-mode`: Shelf 常驻展开（图钉）模式——开关入口、自动隐藏抑制范围、显式隐藏路径、持久化与启动行为。
- `sensor-indicator`: 传感器触发区半透明指示点——显示时机（仅收起时）、外观、多屏行为与更新机制。

### Modified Capabilities

（无——现有 spec 均不涉及窗口显示/隐藏行为，本次不改变任何既有需求的可观察语义。）

## Impact

- `Sources/OpsNotchCore/Models.swift`：`ShelfSettings` 新增 Bool 字段（snake_case CodingKey，容错解码默认 false），旧 `shelf.json` 不受影响。
- `Sources/OpsNotchApp/ShelfWindowController.swift`：`scheduleHide` 汇聚点早退、失 key 观察者跳过、启动时按常驻状态预展开、可见性回调。
- `Sources/OpsNotchApp/SensorManager.swift`：`onMouseExit` 跳过隐藏调度；`SensorView` 增加非 layer 的 `draw(_:)` 指示点。
- `Sources/OpsNotchApp/AppDelegate.swift`：接线 Shelf 可见性回调（无轮询）。
- `Sources/OpsNotchApp/ShelfView.swift` / `SettingsWindowController.swift`：图钉开关与设置行。
- `Sources/OpsNotchApp/Localization.swift`：新增 zh/en 文案。
- `Tests/OpsNotchCoreTests/`：新字段解码默认值 + 编解码往返测试。
- 兼容性：仅新增带默认值的 Codable 字段；不改变拖放、剪贴板去重、安全动作校验与 `static_checks.py` 要求的 API 调用点。

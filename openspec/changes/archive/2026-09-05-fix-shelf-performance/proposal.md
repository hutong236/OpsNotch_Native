## Why

用户实测当前版本 Sensor 触发非常慢、使用中明显卡顿。诊断确认:鼠标进入 Sensor 会同步执行 `model.reload()` → `store.load()`,而 `load()` 并非只读——每次都读盘、解码、再**无条件把整个 shelf.json 写回**;数据文件已膨胀到 214KB / 324 条(拖入路径无去重,重复内容持续累积),排序在每次 SwiftUI body 重算时以 O(n log n) 次比较器调用反复全文评分;剪贴板每次捕获也要经历 3 次全量文件读写(`captureText` 内 `load()` + `touch()` 的 `mutate()` + AppModel 的 `reload()`)。所有开销都落在主线程上,且随条目数增长持续恶化。

## What Changes

- **Sensor 触发路径去除冗余磁盘 I/O**:`onMouseEnter` 不再调用 `model.reload()`(内存状态即权威);`reload()` 仅保留启动与设置导入场景。
- **`load()` 写盘条件化**:仅在解码后实际发生迁移(版本变化)或 TTL 清理(存在过期条目)时写回,普通读取零写入。
- **剪贴板捕获单趟化**:`captureText` 合并为单次 mutate 完成去重判定与写入;`captureClipboardText` 直接应用返回的 store,不再二次 `reload()`。一次捕获从 3 次全量文件操作降为 1 次读 + 1 次写。
- **拖入路径去重语义对齐**:传感器拖入文本/URL 时,若与现有条目内容相同则上浮已有条目(与剪贴板捕获一致);手动新建(`addText`)语义不变,仍允许内容相同的多个条目。
- **条目总数软上限**:存储层引入条目数上限(500),超限时淘汰最旧的非 pinned 且不在 Working Set 的条目;置顶与 Working Set 条目豁免。阻止数据无限膨胀。
- **排序评分预计算**:`SmartShelfRanking.ordered` 改为先为每个条目计算一次 score 再排序,消除比较器内重复全文评分(每轮排序评分次数从 ~2·n·log n 降为 n)。
- **存储编码紧凑化**:shelf.json 写出不再使用 prettyPrinted(仍是合法 JSON,读取兼容,格式协议不变)。
- **剪贴板轮询自适应**:Shelf 面板不可见时轮询间隔放宽到 400ms,可见时保持 100ms;`mouseEntered` 的 `catchIfChanged()` 兜底保留。

不改变的部分(记录为已知权衡,见 design):`show()` 切换 presentation 时重建 AnyView 的整树刷新、行内 `NSWorkspace.shared.icon(forFile:)` 同步取图、以及 `scheduleExpanded` 的 100ms 拖拽优先延迟,本轮均保持现状。

## Capabilities

### New Capabilities

- `shelf-performance`:Sensor 触发与显示路径的性能约束、捕获去重与条目上限的存储增长控制、持久化"按需写盘"纪律及 legacy 兼容性保持。

### Modified Capabilities

(无——现有 `shelf-items`、`shelf-keyboard-retrieval` 等能力的对外行为不变;排序结果语义保持等价。)

## Impact

- **OpsNotchCore**:
  - `ShelfStoreService.swift`:`load()` 写盘条件化;新增条目上限与淘汰;`mutate()` 编码紧凑化。
  - `ShelfStoreService+Clipboard.swift`:`captureText` 重写为单趟 mutate。
  - `SmartShelfRanking.swift`:`ordered` 评分预计算。
- **OpsNotchApp**:
  - `SensorManager.swift`:`onMouseEnter` 移除 `model.reload()`。
  - `AppModel+Clipboard.swift`:`captureClipboardText` 改用 `apply(_:)` 替代 `reload()`。
  - `ClipboardManager.swift`:面板可见性自适应轮询间隔。
- **Tests/OpsNotchCoreTests**:新增 load 幂等(无迁移/清理时不写盘)、拖入去重、上限淘汰、排序等价性测试;现有 legacy 迁移测试必须继续通过。
- **数据兼容**:shelf.json 根对象格式与字段不变(仅空白紧凑化),legacy V0.x/V1.x 迁移不受影响。
- **CI**:`scripts/static_checks.py` 的 API 调用点断言不受影响(不触碰 `registerForDraggedTypes` 等受检字符串)。

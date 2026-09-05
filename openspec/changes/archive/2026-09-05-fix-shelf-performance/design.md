## Context

所有持久化都经 `ShelfStoreService` 的全文件读写(`load()` / `mutate()`,shelf.json 当前 214KB / 324 条)。三个主线程热路径放大了这个成本:

1. `SensorView.onMouseEnter` → `AppModel.reload()` → `store.load()`,而 `load()` 每次都以 prettyPrinted+sortedKeys 重新编码并**无条件写回**整个文件——即使什么都没变。
2. 剪贴板捕获链路一次要走 3 趟全量文件操作:`captureText` 内的 `load()`(查重)+ `touch()` 的 `mutate()`(读+写)+ `captureClipboardText` 收尾的 `reload()`(读+写)。
3. 每次 SwiftUI body 重算,`grouped`/`workingSetItems` 各做一次 O(n log n) 排序,且 `SmartShelfRanking.ordered` 在**每个比较器调用里**重新执行 `score()`(含对整段文本的小写化与语义分类)。

拖入路径(`addText`/`addURL`)没有去重,重复内容无限累积;条目总数没有任何上限。约束:Core 层保持纯逻辑可测、`shelf.json` 与 legacy V0.x/V1.x 根数组格式保持迁移兼容(现有测试不可破坏)、`scripts/static_checks.py` 断言的 API 调用点不可变动。

## Goals / Non-Goals

**Goals:**

- 触发(hover/拖入)与剪贴板捕获路径上,主线程不再做多余的磁盘读写;每次用户操作至多一趟读 + 一趟写。
- 捕获去重语义统一(拖入与剪贴板一致:内容相同→上浮),并给条目总数设上限,阻断数据无界增长。
- 排序从"每比较重复评分"改为"每条目评分一次",排序结果与现状完全等价。
- 现有全部单元测试继续通过,新增行为均有 Core 层测试覆盖。

**Non-Goals:**

- 不做持久化的异步化/debounce 落盘(单文件原子写在去重与紧凑化之后已足够快;异步会引入退出丢写与测试复杂度)。
- 不改 `show()` 切换 presentation 时重建 AnyView 的整树刷新、行内同步 `icon(forFile:)` 取图、100ms 拖拽优先延迟(低频或感知影响小,避免引入状态丢失回归;记录为后续可选项)。
- 不把条目上限做成用户设置(固定 500,未来有需求再加)。
- 不处理文件/文件夹条目的拖入去重(copy 模式语义复杂,数据中占比低)。

## Decisions

### D1. 内存为权威,触发路径完全去掉 `reload()`

所有写路径(`addText`/`addURL`/`captureText`/`mutate` 系列)都返回最新 `ShelfStore` 并由 `AppModel.apply(_:)` 直接更新内存,内存状态与磁盘始终一致。`onMouseEnter` 删除 `model.reload()`;`reload()` 仅保留 `AppModel.init`(启动)一个调用点。Smart 环境上下文已由 focus token 路径的 `refreshSmartContext()` 负责,不受影响。

*替代方案*:后台线程预读 + mtime 校验缓存——引入线程交接与失效复杂度,收益为零(内存本来就是对的),不采用。

### D2. `load()` 写盘条件化

`load()` 解码后仅在两种情况写回:实际发生版本迁移(`migrate` 改变了 version,含 legacy 根数组解码),或 TTL 过期条目非空。其余情况零写入。`normalizeWorkingSet` 的修正不再立即落盘,顺延到下一次 `mutate` 时落盘(仅影响含无效 Working Set ID 的异常数据,可接受)。

*替代方案*:彻底移除 `load()` 的写回、迁移全部移交 `mutate`——但首次启动(无文件)需要 `load()` 建立初始存储,改动面更大;条件化写盘保留现有结构,风险最小。

### D3. `captureText` 单趟化,捕获链路 3 趟 → 1 趟

`captureText` 重写为单次 `mutate`:在 body 内按 `kind == .text && normalized(content) 相同` 查重,命中则刷新 `updatedAt`(保持现有 touch 语义,不加 useCount),未命中则 append。`AppModel.captureClipboardText` 改为 `apply(try store.captureText(text))` + toast,删除 `reload()`。查重为一次 O(总字符数) 线性扫描(当前约 10 万字符,毫秒级),每捕获一次可接受。

### D4. 拖入文本/URL 复用 capture 语义

`ShelfStoreService` 新增 `captureURL`(与 `captureText` 对称:相同 http/https URL → 上浮),`SensorManager.handle` 的 text/url 分支改调 `AppModel` 新增的 capture 入口(内部走 `store.captureText`/`store.captureURL` + `apply`)。手动 `addText`/`addURL` 语义不变(允许重复)。文件/文件夹拖入保持现状(见 Non-Goals)。

### D5. 条目上限 500,淘汰保护 pinned 与 Working Set

`ShelfStoreService` 增加 `maxItems = 500`,在 `mutate` 的 `normalizeWorkingSet` 之后统一执行 `enforceItemLimit`:按 `updatedAt` 升序扫描,跳过 pinned 与 Working Set 成员,删除直到 ≤ 上限。放在归一化之后保证豁免判定基于有效 Working Set。TTL 清理仍先执行(现有逻辑),上限是兜底而非替代。

### D6. 排序评分预计算

`SmartShelfRanking.ordered` 改为两段:先 `items.map { ($0, score(item: $0, ...)) }`(每条目评分恰好一次),再按预计算 score → `updatedAt` → `createdAt` → `id` 排序,比较逻辑与现状逐字段一致。同一排序内 `now` 取值一次,与现状(比较器内多次调用但同一时刻)等价。以单元测试锁定等价性:测试内置旧算法参考实现,随机条目集上两版输出必须逐项一致。

### D7. 编码紧凑化:去掉 prettyPrinted,保留 sortedKeys

shelf.json 写出体积约降为 1/3,读侧不受影响(JSONDecoder 忽略空白)。保留 `sortedKeys` 维持键序稳定,便于人工检查与测试断言。不改变格式协议(仍是根对象/根数组均可解码的标准 JSON),legacy 迁移测试不动。

### D8. 剪贴板轮询间隔自适应(可见 100ms / 不可见 400ms)

保留常驻轮询(ARCHITECTURE.md 要求:两次触碰 Sensor 之间连续复制的中间内容不能丢),但间隔由面板可见性决定:`AppDelegate` 向 `ClipboardManager` 注入 `isVisibleProvider` 闭包,poll 循环每轮按可见性取 100ms 或 400ms。`mouseEntered` 的 `catchIfChanged()` 兜底保留,面板唤起时机不受轮询变慢影响。最坏情况:面板不可见时 400ms 内连续复制两段不同内容,前一段可能漏捕——现状 100ms 同样存在该窗口(连续快过 100ms),非新增缺陷。

## Risks / Trade-offs

- [去重后用户预期"能存多份"] → 与剪贴板路径既有语义一致(本就上浮);手动新建不受限;spec 已明确边界。
- [上限淘汰误删用户数据] → 仅淘汰非 pinned、非 Working Set 的最旧条目;TTL 清理已有同类先例;500 远大于当前 324,短期不会触发。
- [历史上若有人依赖"读时无条件写回"修复数据] → 迁移与 TTL 两条修复路径仍写盘;Working Set 归一化修正顺延到下次 mutate,影响面仅限异常数据。
- [排序等价性回归] → 等价性单元测试 + 现有键盘导航/置顶测试共同锁定;比较 tie-breaker 逐字段保持。
- [紧凑化破坏外部工具读取] → 文件仍是标准 JSON;无其他工具依赖其空白格式。
- [轮询放宽漏捕 400ms 内的连续复制] → 见 D8,非新增缺陷,面板可见时仍 100ms。

## Migration Plan

无数据迁移:格式协议不变,存量 shelf.json 直接兼容。按提交顺序落地:Core 存储层(含测试)→ 排序预计算 → App/Sensor/Clipboard 接线 → 人工验收。任一问题可按提交粒度 revert 回滚。

## Open Questions

无。上限取值 500 为当前规模(324)之上的合理默认,若未来需要用户可配,属独立变更。

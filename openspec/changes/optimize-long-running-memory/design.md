## Context

应用长期驻留时需要区分真正的泄漏与“为功能长期持有但其实没必要”的对象。当前 ClipboardManager 的短时重复抑制把上一份完整文本/路径数组保存为属性，复制大文本后会在 Shelf 数据之外额外长期持有一份相同量级 payload。LocalFileSearchService 使用 `Task.detached` 做文件系统扫描，外层查询任务取消后 detached 工作没有显式取消传播，快速输入会造成旧查询短时间并发堆叠。FloatingPreviewController 关闭面板时只 `orderOut`，仍保留 hostingView；最后一次预览的大图或大文本视图树因此继续驻留。

## Decisions

### D1. 去重状态只保留固定大小指纹

使用进程内 `Hasher` 对规范化文本或路径序列生成 digest，同时记录 UTF-8 字节数与项目数。1 秒重复抑制窗口内比较指纹，不再把完整 payload 保存为 Manager 属性。Hasher 只服务当前进程内短时比较，不需要跨启动稳定。

### D2. 保留现有剪贴板轮询频率

不为了降低 CPU 而继续放宽 400ms 空闲轮询，因为这会扩大连续复制漏捕窗口。本变更先降低内存持有，不改变捕获体验。

### D3. 搜索先 debounce 再启动文件系统工作

在启动 detached 扫描前等待 120ms。新输入会取消旧外层任务，旧任务在 debounce 阶段直接退出，减少无意义扫描。

### D4. detached 搜索显式继承取消

使用 cancellation handler 在外层任务取消时调用 detached task 的 `cancel()`；同步目录遍历在路径、根目录与目录项循环中检查取消并立即返回，避免旧查询继续累积临时数组/Set。

### D5. 关闭悬浮预览即释放内容树

预览面板对象本身继续复用，关闭时 `orderOut` 后将 `contentView` 与 `hostingView` 置空。下次 show 再创建 hosting view。这样不改变面板位置/样式语义，同时允许 NSImage、NSTextView 与 SwiftUI 状态树在关闭后释放。

## Risks

- 内容指纹理论上存在哈希碰撞；同时比较 digest、字节数、项目数，且仅用于 1 秒短时抑制，实际风险极低。
- 120ms debounce 会让本地文件结果最多晚约 120ms 出现，但应用搜索与 Shelf 自身过滤不受影响，换取快速输入时更稳定的资源占用。
- 预览重新打开时会重新创建 hosting view；这是一次低频构建成本，换取关闭状态不长期占用大内容内存。

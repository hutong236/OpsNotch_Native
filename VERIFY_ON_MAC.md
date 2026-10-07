# Ops Notch Native V2.0 macOS 验收

## 1. 编译

```bash
swift --version
swift test
swift build
python3 scripts/static_checks.py
./scripts/run_dev.sh
```

## 2. 默认隐藏

启动后：

- 不显示 Dock 图标。
- 菜单栏显示单色 SF Symbol。
- 屏幕上没有常驻黑色胶囊。
- 主 Shelf 默认隐藏。

## 3. 鼠标触发

鼠标移动到每块显示器顶部中央：

- Shelf 立即出现。
- Shelf 出现在当前触发的显示器。
- 鼠标移到 Shelf 后不能提前自动隐藏。
- 移出后自动收起。

## 4. 文字原生 Drag

分别在 TextEdit、Notes、Safari、VS Code：

1. 选择一段文字。
2. 按住选中文字拖动；如果系统已开启三指拖移，也测试三指拖。
3. 拖到屏幕顶部 Sensor。
4. 出现 Drop UI。
5. 不继续移动，原地松开。
6. Text 必须加入 Recent。
7. 点击该条目必须 Copy。

## 5. Clipboard Catch

1. 启动后直接碰刘海，不应导入启动前旧剪贴板。
2. `⌘C` 复制 `192.168.0.205`。
3. 碰刘海。
4. Recent 自动增加该文字。
5. 再碰一次，不得重复增加。
6. 点击该条目 Copy 后，再碰刘海，也不得把自己的 Copy 再次加入。

## 6. Finder Drag

测试：

- 单文件
- 多文件
- 文件夹
- `.app`

拖到 Sensor 后原地松开。

Reference 模式不得删除/移动原文件；Copy-in 必须写入 `shelf-files/`。

拖入落点补充:面板已展开(悬停刘海打开)时,把文件拖到抽屉列表区松手也应入柜;
拖到"Drop UI"提示条上松手同样入柜。诊断可用 `./script/build_and_run.sh --logs`
实时观察 `sensor drop` / `shelf drop` 日志。

## 7. URL Drag

Safari 地址、网页链接拖到 Sensor：

- HTTP/HTTPS → URL Item
- 点击 → 默认浏览器打开

## 8. 多显示器

至少双屏：

- 每块屏幕都可独立触发。
- A 屏触发 → A 屏显示。
- B 屏触发 → B 屏显示。
- 插入显示器后无需重启即可使用。
- 拔出显示器无残留窗口。
- 修改排列/分辨率后 Sensor 自动重新定位。

## 9. Pinned / Recent

- Pin 后移动到 Pinned。
- 取消 Pin 回 Recent。
- Pinned 永不过期。
- Recent TTL 按设置清理。

## 10. Quick Look / Finder / App

- File Quick Look 正常。
- Reveal in Finder 正常。
- Folder 点击打开。
- `.app` 点击启动。

## 11. Drag Out

- 单个文件从 Drag Handle 拖到 Finder/Desktop。
- Command 选择多个文件后，从已选条目的 Drag Handle 拖出，应形成多个 Native DraggingItem。
- Text 拖到 TextEdit 应成为文本。
- URL 拖到浏览器应成为 URL。

## 12. Safe Action

允许：

```text
/Applications/Terminal.app
https://example.com
```

禁止：

```text
rm -rf /
ssh root@host
javascript:...
```

## 13. 设置

验证：

- 中文 / English
- 所有显示器 / 鼠标屏幕 / 主屏 / 最近屏幕
- Reference / Copy-in
- Recent TTL
- Login at startup

## 14. 正式 App

```bash
./scripts/build_app.sh
open "build/Ops Notch.app"
```

然后确认：

```bash
lsof -i :1420
```

Ops Notch 不应创建任何 1420 监听端口。

## 15. 全局呼出快捷键

1. 设置 → 通用 → 呼出快捷键。
2. 点击录制,按下 `⌃⌥O`;录制区显示 `⌃⌥O`,立即生效。
3. 在其他应用(如 Safari)前台按下 `⌃⌥O`:Shelf 在鼠标所在屏幕展开,**前台应用不被切换/激活**,按键不被穿透(不会打出字符)。
4. 再按一次:Shelf 收起(切换语义)。
5. 重启应用:快捷键仍生效。
6. 冲突路径:录制一组已被占用的组合(如 `⌘Space`),设置页出现红字冲突提示,原快捷键继续生效。
7. 非法组合:录制仅 `⇧+字母` 或纯字母,出现"需包含 ⌘/⌃/⌥"提示且不被接受。
8. 清除:录制区按 `⌫`,快捷键恢复"未设置",热键注销。
9. 拖放忽略:拖文件悬停刘海(drop 态)时按热键,面板状态不变,拖放正常完成。

## 16. 键盘取回流

1. 热键呼出(或悬停展开)后:搜索框已聚焦,直接打字即过滤,无需点击。
2. 列表第一行默认白描边高亮(与多选蓝底可区分);`↑`/`↓` 移动高亮,边界停止;继续打字过滤后高亮回到第一行。
3. `Enter`:高亮条目内容进入剪贴板,显示"已复制",面板约 0.6s 后自动隐藏;回到原应用 `⌘V` 可粘贴;再次展开面板,剪贴板捕获**不**把这条复制回灌为重复条目。
4. `Esc`:面板立即隐藏,剪贴板不变。
5. 失焦隐藏:面板展开后点击其他应用窗口,面板自动收起,不留失焦浮窗;右键菜单打开期间操作菜单项,面板不被误隐藏。
6. 上浮:复制 Recent 中部某条目后重新展开,该条目已在 Recent 顶部;复制 Pinned 条目,它仍在 Pinned 分区内上浮。
7. 编辑弹窗打开时 `Enter` 仍走"保存",不被键盘流接管。
8. Tab 回到搜索:鼠标点击列表中某条目使焦点离开搜索框后按 `Tab`,搜索框重新聚焦,继续打字即可过滤。
9. 搜索框聚焦时按 `Tab`:焦点保持在搜索框不移出,面板内其他控件不因 `Tab` 获焦,键盘流不中断。
10. 编辑弹窗打开时 `Tab`:在文本框内作为普通输入,不触发搜索框聚焦。

## 17. Command-first 搜索（Phase 4）

1. 展开面板：搜索框显示“搜索或输入命令…”，没有常驻类型 chips；搜索框帮助提示包含 `d2`、`~/Downloads`、`type:file report`、`@fav`。切换中文/English 后提示和空态双语言正确。
2. 输入普通关键词，Shelf / Working Set / Finder 快捷路径仍按已有匹配与排名显示，条目 ID、分区计数与键盘高亮一致。
3. 输入 `type:file report`：仅匹配 file/folder 条目和 Finder 快捷路径；safe action 不混入。输入 `type:folder report`：Shelf 仅匹配 folder；`type:text`、`type:url`、`type:application`、`type:action` 对应各自类型。残余查询保留大小写与空格。
4. 输入 `@fav token`：仅显示匹配的 pinned 收藏，包括已在 Working Set 的收藏且不重复；未收藏的 Working Set / Recent 与 Finder 路径不混入。
5. 输入 `d` / `d2` / `d 2`，以及已有别名 `desktop` / `桌面` / `desktop 3` / `桌面 4`：仅显示对应 Desktop 命令（大小写与额外空白兼容）；Enter 保持现有桌面列表/切换处理与能力限制。不完整/非法命令（`d0`、`d2 report`、`desktop app`、`desktop2`、`桌面 01`、`type:unknown report`）作为普通搜索，不执行操作。
6. 输入 `~/Downloads` 或绝对目录（含空格）：仅显示 Finder 路径意图；Enter 走现有 Finder 安全校验和打开处理。不存在路径、非目录与无权限路径遵循现有错误提示；不得执行 shell 文本。
7. 查询变化后高亮回到第一条可见结果；`↑` / `↓` / Enter / Esc 保持行为。查询为空后恢复普通内容；无匹配类型时显示“没有匹配的条目”。
8. 搜索编辑器中按 Space 必须输入空格（可连续输入 `type:file quarterly report`）；焦点在编辑器外时，Space 对可预览文件/图片或文本保持现有预览，剪贴板不变。带修饰键的 Space 不触发预览。
9. `⌘1`…`⌘6` 不再切换隐式类型状态或被 chip 快捷键消费。收起/展开保留会话查询；重启不恢复临时命令/过滤，不新增持久化字段。
10. Enter 复制现有 Shelf 文件/文本时保持 fileURLs / 文本语义及 Clipboard Catch baseline；Finder 专用热键仍清除临时搜索/筛选后定位默认目录。

## 18. Finder 快捷路径响应速度

1. 设置 → Finder 快捷路径，将打开方式设为“系统默认（推荐）”。
2. 在 Finder 未打开目标目录时呼出快捷路径面板并按回车：面板应立即收起，Finder 随即打开目录，不应出现自动化权限提示或约 1 秒的空等。
3. Finder 已打开或未打开时各连续测试 5 次，均不应因 `osascript` 超时而延迟；活动监视器中不应因系统默认模式启动 `osascript`。
4. 将打开方式切换为“优先在现有 Finder 新建 Tab”：已有同路径窗口时应直接前置复用；无同路径窗口时创建 Tab；权限拒绝或超时后仍应在最多约 1.5 秒内回退到系统默认打开。

## 19. Finder + Clipboard 统一 Quick Shelf

1. 配置主 Quick Shelf 呼出快捷键、Finder 默认目录和至少 2 个收藏目录；复制若干文字并在 Finder 复制一个文件。
2. 使用主快捷键呼出：列表从上到下应为 `Finder 快捷目录 → Pinned → Recent`，默认目录始终是 Finder 分区第一项。
3. 连续按 `↓`：高亮必须从 Finder 最后一项连续进入 Pinned/Recent；超过一屏后列表同步滚动，当前高亮始终可见。
4. 输入收藏目录名称或路径的一部分：同一搜索框能过滤到 Finder 目录；输入剪贴板文本的一部分能过滤到 Shelf 条目。
5. 切换“文本 / URL / 应用”：Finder 分区隐藏；切换“全部 / 文件”：Finder 分区恢复。
6. Finder 目录高亮后按 `Enter`：Quick Shelf 收起并按当前 Finder 打开模式打开目录；收藏目录的使用次数/最近使用排序随后更新。
7. Finder 行鼠标单击打开目录；悬停点击复制按钮或右键“复制路径”，随后可在 TextEdit 粘贴完整路径。
8. Shelf 文本高亮后按 `Enter`：仍复制文本；Shelf 文件高亮后按 `Enter`：到 Finder 执行 `⌘V` 必须粘贴为真实文件，而不是文件名/路径文本。
9. 使用旧的 Finder 专用快捷键：不得再弹出第二套路径面板，应打开同一个 Quick Shelf，并清除临时搜索/类型筛选后定位默认 Finder 目录。
10. Finder 路径高亮时按 `Space` 不触发 Quick Look；Shelf 文件高亮时 `Space` 仍正常预览。
11. 双屏分别通过主快捷键/刘海触发统一面板，仍应显示在预期屏幕；Finder 打开后不残留第二个 Ops Notch 面板。
12. 连续复制 20 段不同文字仍全部进入 Recent；Ops Notch 自身复制的文字/文件仍不得回灌为重复条目。

## 20. Smart Quick Shelf V2（v2.3.0）

1. 准备至少 6 个 Shelf 条目：普通文本、`192.168.10.40`、`ssh admin@192.168.10.40`、`kubectl get pods -n prod`、一个 URL、一个真实文件；界面应对 IP / SSH / 命令 / 路径或 URL 显示轻量语义提示，不增加明显行高。
2. 将文件、kubectl 命令、IP、SSH 四项加入 Working Set：展示顺序应为 `Finder 快捷目录 → 工作集 → Pinned → 智能最近`；同一条目不得同时在 Working Set 与 Recent 重复出现。
3. 退出并重新启动 Ops Notch：仍存在的 Working Set 条目应恢复；删除 Working Set 中一个 Shelf 条目后，该 ID 应自动从工作集清理；点击工作集“清空”后全部移除但原 Shelf 内容仍保留。
4. 以前台 Finder 呼出 Quick Shelf：在最近时间相近时，文件/文件夹/路径类相对普通文本应获得更高排序；底部上下文提示显示 `Smart · Finder`。
5. 以前台 Terminal、iTerm2 或 Warp 呼出：命令 / SSH / IP / 路径类相对普通文本获得更高排序；底部显示 `Smart · Terminal`。切换到 Safari/Chrome/Edge/Firefox/Arc 后，URL/文本获得浏览器上下文加权并显示 `Smart · Browser`。
6. 在 Terminal 前台输入一个只精确命中普通文本标题的搜索词，同时存在更符合终端上下文但不相关的命令条目：精确/前缀搜索结果必须排在不相关命令之前，验证 query relevance 高于 App context。
7. 对同一非置顶条目连续成功取回数次，再与创建/更新时间接近但从未使用的同类条目比较：前者应因 useCount / lastUsedAt 获得排序加权；重启后该排序信号仍有效。
8. Working Set 中的真实文件高亮后按 `Enter`：到 Finder 执行 `⌘V` 必须粘贴为真实文件；不能变成文件名或路径文字。Recent/Pinned 中同一行为也必须一致。
9. 输入已打开过的最近文件名称，或 Finder 默认/收藏目录第一层子项名称：可以出现“本地文件结果”；本地文件按 `Enter` 复制真实文件，本地文件夹按 `Enter` 打开 Finder；这些临时结果不得写入 `shelf.json`。
10. 在包含大量子目录的收藏目录中搜索：只应匹配收藏根目录的第一层项目，不应递归进入孙级目录；搜索过程中 UI 不应出现明显全盘扫描卡顿，也不应弹出新的文件访问权限请求。
11. 准备足够多的各类结果并连续按 `↓`：高亮应依次跨 `Finder → Working Set → Pinned → Smart Recent → Local File Results`，超过一屏后列表同步滚动；`↑` 反向行为一致。
12. 本地文件结果高亮后按 `Space`：真实文件可 Quick Look，文件夹不触发 Quick Look；Finder 快捷路径仍不触发 Quick Look。
13. 对 `ssh root@host`、`kubectl delete ...`、`rm ...` 等文本验证：V2 只允许识别/显示/排序/复制，绝不能自动执行，也不应启动 Terminal、shell、SSH 或产生网络连接。
14. 打开“系统设置 → 隐私与安全性”验证：本功能不应新增 Accessibility / Input Monitoring 权限请求；应用也不得读取 shell history、浏览器历史或钥匙串内容。
15. 连续复制 20 段不同文字、复制 Finder 文件、从 Working Set/Recent 二次取回文件各执行多轮：Clipboard Catch 仍完整记录外部复制，Ops Notch 自身复制不回灌，文件始终保持 file URL pasteboard 语义。
16. 双显示器分别在 Finder / Terminal / Browser 前台呼出 Smart Quick Shelf：面板仍出现在预期屏幕，当前 App 上下文排序正确，多屏 Sensor / Finder 打开能力无回归。

## 21. 桌面与跨显示器窗口移动（macOS 26.6.2）

前置条件：允许 **Ops Notch** 的辅助功能权限。窗口应非全屏、非最小化，应用不分配到所有桌面。跨屏指定独立桌面需要扩展显示并开启“显示器具有单独的空间”；目标显示器当前也需显示普通桌面。授权后重新激活源窗口，再呼出 Shelf。

用户已反馈 #98 FinderSpaceDemo 0.2 测试成功。以下清单用于正式工具的独立回归；该反馈不等于下列所有 App、动作与布局均已验收。

1. 在显示器 A 的桌面 1 激活 Sublime Text 窗口；呼出 Shelf，输入 `d` 回车。顶部“操作窗口来自”必须是 Sublime Text。
2. 普通选择另一个桌面：仅切换桌面，Sublime 窗口仍留在源桌面。
3. 重新激活源窗口呼出工具，从“移动当前窗口到…”中选择同屏另一个普通桌面：只移动该窗口。
4. 从“移动当前窗口并跟随到…”选择目标：窗口、键盘输入焦点和鼠标一起到达目标；不必再点击窗口才能输入。
5. 按住 ⌥ 再点击目标桌面行，或按住 ⌥ 后用 ↑↓ 选中目标并按 Enter：结果与步骤 3 一致；按住 ⌥⇧ 重复操作，结果与步骤 4 一致。底部提示应明确写出“选择桌面行”，只有 ⇧ 时仍是普通切换。
6. 跨屏分别测试 A → B 当前桌面（带 ✓）、A → B 非当前桌面（不带 ✓），随后 B → A。检查窗口完整出现在指定屏/桌面；只移到 B 当前桌面不算指定非当前桌面移动成功。
7. 使用不同缩放比例及左侧/上方排列的显示器测试。窗口通常保持点尺寸；目标屏过小时按需缩小，不被放在屏幕外或菜单栏/Dock 下方。
8. Finder、Sublime Text、Safari 分别打开两个窗口，激活其中一个后重复，确认每次只移动呼出工具前的窗口，菜单显示正确源应用。
9. 在菜单中选定目标前重排桌面：必须仍按原目标 Space ID 移动；目标删除/移到其他屏后明确失败，不能按旧序号移动其他桌面。
10. 操作期间拔除/重排显示器：停止操作并提示布局变化。发生部分移动后检查实际位置，重新激活窗口即可再次操作。
11. 尝试全屏、Split View、最小化、多 Space 窗口或关闭已捕获窗口：明确拒绝，不退回到移动其他窗口。
12. 移到本来所在的普通桌面：安全完成；多 Space 窗口即使包含目标 ID 也不能当作成功。
13. 快速重复桌面命令：不得并发移动/抢鼠标；出现失败提示后可重新激活窗口重试。
14. `./script/build_and_run.sh --telemetry` 的 `desktop-window` 日志应包含同一 `captured source window`、`move before` 和 `verified move`。跨屏有 `cross display plan`、`display staged`；目标恰好是该屏当前桌面时可能通过 AX 放置直接完成，不调用私有 Space API。失败保留最终 Space/位置，未确认成功时不继续跟随。
15. 普通剪贴板搜索取回与 Esc 收起继续归还原应用焦点；桌面移动后不得被旧 Shelf 回调激活回原桌面。

CI 在 `macos-26` 运行坐标/连续确认序列单元测试、`scripts/verify_desktop_space_compatibility.c` 符号探针、`scripts/verify_desktop_window_move.m` 生产桥接的自有窗口同 Space 调用、正式 App 编译和签名打包。日志明确输出 `CROSS_SPACE_NOT_TESTED; CROSS_DISPLAY_NOT_TESTED; EXTERNAL_APP_NOT_TESTED`；外部 App 的上述操作仍需真机验收。


## 22. Ops Notch 3.0 回归基线

在 3.0 重构的每个 Phase 合并前，除上面的专项验收外，至少重复以下关键路径：

1. **数据兼容**：使用 v2.8.5 生成的 `shelf.json` 启动 3.0 构建，条目、Finder 快捷目录、Working Set、语言、显示位置、常驻展开和快捷键配置必须可读；保存后不得无故丢字段或用户条目。
2. **剪贴板语义**：外部连续复制文字/图片均可捕获；Ops Notch 自身 Copy 不回灌；文件二次取回仍以 file URL 粘贴，不退化为路径文本。
3. **拖放**：文件、文件夹、URL、文字、File Promise 在 Sensor、已展开 Shelf 和 Drop UI 上均保持现有入柜语义；Reference 不移动原文件，Copy-in 写入受管目录。
4. **Finder / Desktop / Workspace**：Finder 快捷目录、桌面切换、窗口移动/跟随仍走现有系统服务，不因 UI 重构改变底层动作。
5. **焦点与键盘**：热键呼出后搜索可直接输入；方向键、Enter、Space、Esc、Tab 行为与当前验收一致；当目标横向功能区为空时，当前高亮保持不变。
6. **多显示器 / Spaces**：触发屏幕、拔插显示器、全屏 Space、独立 Space 与窗口移动按现有章节继续验证。
7. **Quick Look / Preview**：真实文件 Quick Look、文本浮动预览、Finder 路径不误触 Quick Look。
8. **外观与语言**：Light / Dark、中文 / English 均可用；Phase 5 起增加 Reduce Motion 专项验收。
9. **性能**：不得重新引入 UI polling、递归文件扫描或每次 SwiftUI `body` 重建全部排序。沿用 invalidation-driven snapshot 基线。
10. **安全边界**：SSH、kubectl、rm 等只允许识别/显示/排序/复制，绝不自动执行。

> Phase 4 command-first 搜索验收见第 17 节；旧类型 chips 与数字切换快捷键已移除。


## 23. Ops Notch 3.0 Presentation & Motion

1. 使用主快捷键呼出 Shelf：直接进入 Expanded，搜索框聚焦；再次按快捷键立即收起。
2. 拖入真实文件/文字到顶部 Sensor：进入 Drop Target；松手成功后只显示 Confirmation，不显示完整列表或 Pinned/Recent。
3. 开启“常驻展开”后重复拖入：Confirmation 结束后恢复 Expanded；关闭常驻时 Confirmation 结束后隐藏。
4. Drop Target 展示期间按主快捷键不得抢走拖放状态；原生拖放仍须完成。
5. 键盘流回归：↑/↓ 连续选择，←/→ 跨区，Enter 执行主动作，Esc 收起，⌘P 收藏，⌘D 删除；无可执行目标时快捷键不得吞掉无关按键。
6. 搜索框编辑时 Space 必须输入空格而不是 Quick Look；焦点离开搜索框且高亮可预览条目时 Space 才触发预览。
7. Tab / Shift-Tab 在 Shelf 键盘流中保持或取回搜索框焦点；Item Editor 打开时 Tab 仍由编辑器自身处理。
8. 打开“系统设置 → 辅助功能 → 显示 → 减弱动态效果”后重复 Drop Target → Confirmation → 隐藏：面板不得做位置/缩放移动，只允许极短淡入淡出；关闭后恢复空间过渡。
9. 双显示器分别执行快捷键与拖放：Expanded / Drop Target / Confirmation 均留在触发屏，收起后不得残留透明窗口。
10. Finder / Desktop / Clipboard 的主动作与焦点归还行为保持 Phase 0 基线，不因 Presentation Coordinator 或 Keyboard Controller 抽离而改变。


## 24. Ops Notch 3.0 Settings & Menu

1. 打开菜单栏 Ops Notch → 设置：窗口应为左侧 sidebar + 右侧详情，不再出现单页超长滚动设置。
2. Sidebar 顺序固定为：通用、Shelf、剪贴板、Finder、工作区、输入法、快捷键、高级；中英文切换后各项均应正确本地化。
3. 切换每个 Sidebar 项时窗口不应闪烁、重建或改变已编辑状态；Finder 快捷路径与输入法规则继续使用现有真实服务。
4. 修改语言、显示位置、拖放辅助、常驻展开、文件放置方式、Recent 清理、主快捷键后关闭设置，再次打开时值必须保持。
5. 修改 Finder 默认目录、Finder 快捷路径、Finder 专用快捷键后重启 App，配置必须保持且行为与 2.8.x 一致。
6. Clipboard 页面只展示真实存在的自动捕获状态与 Recent 清理策略；不得出现无法生效的伪开关。
7. Workspace 页面只说明现有 Desktop 命令与窗口移动能力；不得声称存在尚未持久化的 Workspace Profile 设置。
8. 菜单栏菜单图标与分组显示正常；Phase 7 起不再显示只读版本项；“退出 Ops Notch”只能通过显式菜单操作，不新增 ⌘Q 快捷键。
9. 将设置窗口缩到最小尺寸、再放大；sidebar 与详情均不得裁切关键控件，Finder/Input Method 长内容可滚动。
10. 在浅色/深色模式和 Reduce Transparency 下检查设置页：不应出现固定白底、不可读文字或侧栏自定义重色背景。


## 25. Ops Notch 3.0 Phase 7 Polish

1. **主 Shelf 层级**：在浅色/深色分别展开 Shelf，标题、副标题、Command Bar、Section、Row、Inspector、Footer 的层级清晰；不存在一眼可见的旧版控件样式、固定蓝色高亮或突兀的裸字号。
2. **交互状态**：同一条目依次验证 Default / Hover / Keyboard Focus / Selected / Pressed；鼠标与键盘高亮语言一致，主动作整行可用，图标按钮有 tooltip 与 VoiceOver label。
3. **Drop / Peek / Confirmation**：拖入时 Drop Target 使用系统 accent 与统一圆角；Peek 保持轻量，不显示搜索/筛选/设置；成功落放必须进入独立 Confirmation（显示“已放入抽屉 / Added to Shelf”），不能复用 Peek 或 Expanded。
4. **Inspector 比例**：文本、图片、文件、URL 各检查一项；Inspector 不挤压列表到不可用宽度，主动作与 Row 使用同一 ActionIntent，切换条目不闪白、不跳位。
5. **菜单栏控制中心**：菜单只保留“打开 Shelf / 常驻展开 / 设置 / 退出”四类控制（分隔线除外）；不再显示“新建文字”与只读版本项。切换“常驻展开”后菜单勾选状态与 Shelf 实际状态同步。
6. **Settings 视觉一致性**：Sidebar、页面标题、Card、Row、Picker 宽度遵循同一 Design System；窗口缩到最小尺寸再放大时不裁切关键控件，Finder/Input Method 长内容可滚动。
7. **本地化完整性**：中文/English 下检查 Shelf 副标题、上下文标签、选择栏、菜单与 Settings；除 Finder、Smart、URL 等产品/技术词外，不出现中英文硬编码混排。
8. **辅助功能**：开启 Reduce Motion、Increase Contrast、Reduce Transparency 分别复测 Shelf/Inspector/Settings；Reduce Motion 不出现位置或缩放动画，图标按钮可由 VoiceOver 读出用途。
9. **多显示器与 Space**：至少双屏分别呼出、拖入、Peek/Expanded/Confirmation；面板必须留在触发屏，切换全屏 Space 后无残留透明窗口。
10. **清理确认**：主界面无常驻类型 chips、无旧 Preview Pane、无重复 Finder/Desktop/Shelf Row 实现；Quick Look、Finder 打开、文件 pasteboard、Clipboard Catch 与 Phase 0 回归基线一致。

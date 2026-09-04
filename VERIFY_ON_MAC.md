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

## 17. 类型筛选

1. 面板展开后搜索框下方出现"全部 / 文件 / 文本 / URL / 应用"五个筛选位,默认"全部"。
2. 点击"文件":仅剩 file/folder 与 openPath 类 action 条目;点击"URL":url 与 openURL 类 action 条目;Pinned/Recent 分区头与计数随筛选正确变化。
3. `⌘1`~`⌘5` 依次切换五个筛选位,chips 选中态同步;`⇧+数字`、`⌃+数字` 不误触。
4. 筛选或搜索变化后,键盘高亮回到过滤结果第一行;`↑`/`↓`/`Enter` 复制/`Esc` 在筛选状态下行为正常。
5. 焦点不在搜索框时按 `Space`:高亮条目(文件/图片)弹出 Quick Look,面板保持展开、剪贴板不变。
6. 搜索框聚焦时按 `Space`:输入空格,不触发预览。
7. "文本"筛选下拖入一个文件:筛选自动回"全部",新文件条目出现在 Recent 顶部。
8. "应用"筛选且无应用条目:显示"没有匹配的条目"(与清柜后的空柜提示区分)。
9. 面板收起再展开筛选保持;重启应用后筛选恢复"全部"。
10. 设置页切换中文/English,chips 与空态文案双语言正确。

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

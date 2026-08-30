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

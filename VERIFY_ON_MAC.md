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

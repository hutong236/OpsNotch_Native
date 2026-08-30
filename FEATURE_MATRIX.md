# V1.x → Native V2.0 功能对照

| 功能 | Native V2.0 |
|---|---|
| 默认隐藏 | ✅ NSPanel |
| 刘海触碰展开 | ✅ NSTrackingArea |
| 所有显示器 Sensor | ✅ NSScreen.screens |
| 显示器热插拔 | ✅ didChangeScreenParametersNotification |
| 文件拖入 | ✅ NSDraggingDestination |
| 文件夹拖入 | ✅ |
| 多文件拖入 | ✅ |
| 选中文字拖入 | ✅ AppKit Pasteboard |
| 三指拖文字 | ✅ 来源 App 发出系统 Drag 即可 |
| URL 拖入 | ✅ |
| Clipboard Catch | ✅ NSPasteboard.changeCount |
| Text 点击复制 | ✅ |
| File / Folder 打开 | ✅ NSWorkspace |
| App 启动 | ✅ NSWorkspace |
| Safe Action | ✅ 仅 path/http/https |
| Quick Look | ✅ QLPreviewPanel |
| Reveal in Finder | ✅ |
| Pinned / Recent | ✅ |
| Search | ✅ |
| Recent TTL | ✅ |
| Reference / Copy-in | ✅ |
| 单项拖出 | ✅ Native Drag Session |
| 多选拖出 | ✅ DraggingItem 数组 |
| 中英文 | ✅ 运行时切换 |
| 登录启动 | ✅ SMAppService |
| 菜单栏 | ✅ NSStatusItem + SF Symbol |
| Dock 图标 | ✅ 不显示 |
| 自定义全局快捷键 | ❌ 按产品方向删除 |
| localhost / Vite | ❌ 不存在 |
| Node.js / npm | ❌ 不需要 |

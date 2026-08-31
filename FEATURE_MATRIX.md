# 功能矩阵

| 能力 | Native V2 | 说明 |
|---|---:|---|
| 默认隐藏 | ✅ | Accessory App，无 Dock 图标 |
| 刘海触碰展开 | ✅ | AppKit Tracking Area |
| 所有显示器感应区 | ✅ | 每块屏幕独立 Sensor |
| 显示器热插拔 | ✅ | 事件驱动重建，无轮询 |
| 文件、文件夹、多文件拖入 | ✅ | 原生 Dragging Destination |
| 选中文字拖入 | ✅ | 依赖来源应用提供系统 Drag Pasteboard |
| URL 和应用拖入 | ✅ | HTTP/HTTPS 与 .app |
| Clipboard Catch | ✅ | changeCount 去重 |
| Pinned / Recent | ✅ | 支持上浮、清理和 TTL |
| 搜索与类型筛选 | ✅ | 全部、文件、文本、URL、应用 |
| 键盘取回流 | ✅ | 方向键、Enter、Space、Esc、Command+1 至 Command+5 |
| 单项与多项拖出 | ✅ | Native Drag Session |
| 文件复制到 Finder | ✅ | 原生文件 URL Pasteboard |
| Quick Look / Finder 定位 | ✅ | 系统能力 |
| 浮动预览 | ✅ | 支持可预览条目 |
| Reference / Copy-in | ✅ | 两种文件存储策略 |
| 中英文切换 | ✅ | 运行时切换 |
| 登录启动 | ✅ | SMAppService |
| 可选全局热键 | ✅ | 默认关闭，Carbon 注册式热键，无 Input Monitoring 权限 |
| 安全动作 | ✅ | 仅本地绝对路径和 HTTP/HTTPS |
| 本地 Web 服务 | 不存在 | 不监听 localhost 端口 |
| Node.js / npm 依赖 | 不需要 | Swift Package Manager only |

详细验收步骤见 VERIFY_ON_MAC.md。
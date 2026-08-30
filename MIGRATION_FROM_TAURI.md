# 从 Tauri V1.x 迁移到 Native V2.0

## 不再需要

Native V2 删除：

- React
- TypeScript
- Vite
- Node.js
- npm
- Tauri WebView UI
- `localhost:1420`
- Tauri Global Shortcut Plugin
- Tauri Drag Plugin
- Tauri Clipboard Plugin

## 保留数据

Native V2 默认继续读取：

```text
~/Library/Application Support/lab.hutong.opsnotch/shelf.json
```

兼容逻辑包括：

- Store object
- 早期根数组格式
- `ip` / `command` → `text`
- `created_at`
- `updated_at`
- `storage_mode`
- `action_kind`
- `extension`
- 未识别的旧字段自动忽略

建议第一次启动 Native V2 前备份：

```bash
cp -R "$HOME/Library/Application Support/lab.hutong.opsnotch" \
      "$HOME/Desktop/opsnotch-backup"
```

## V1 与 V2 可以同时装吗？

不建议同时运行，因为两者默认使用同一个 `shelf.json`。

迁移时先退出 V1，再启动 V2。

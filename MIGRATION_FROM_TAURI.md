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
- 未识别的字段随所属根对象、设置、条目、Finder 快捷路径及两个快捷键原位保留，保存与迁移时重新编码；不增加包装字段或存储版本。
- 当前已知字段始终由当前值决定；清空可选字段、删除/过期/淘汰条目或截断路径不会从旧文档恢复数据。
- 未知字段中的有符号/无符号 64 位整数精确保留，其他受支持数值使用 Decimal（不保证原始数值文本格式）。超出支持范围的未知数值使加载或修改失败，避免静默丢失后覆盖原文件。

建议第一次启动 Native V2 前备份：

```bash
cp -R "$HOME/Library/Application Support/lab.hutong.opsnotch" \
      "$HOME/Desktop/opsnotch-backup"
```

## V1 与 V2 可以同时装吗？

不建议同时运行，因为两者默认使用同一个 `shelf.json`。

迁移时先退出 V1，再启动 V2。

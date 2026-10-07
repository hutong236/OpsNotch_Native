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

## 未知数值与已退休字段的边界

持久化入口 `ShelfStoreService` 在 Codable 解码前读取未知字段的原始数值文本，比较其精确十进制值与 Decimal 重编码结果；超过精度/范围时拒绝加载或修改，不写回文件。已知字段仍沿用原有数值归一化。直接使用通用 `JSONDecoder` 解码模型没有原始数值文本，因此仅持久化服务入口提供超精度拒绝保证；不要绕过该入口加载并覆盖用户存储。

版本 25 已明确移除的七个设置键仍按原迁移规则丢弃：`menu_bar_management_enabled`、`menu_bar_auto_hide_seconds`、`menu_bar_start_collapsed`、`menu_bar_always_hidden_enabled`、`menu_bar_panel_enabled`、`menu_bar_animation_enabled`、`menu_bar_last_state`。此例外不按前缀匹配，其他未来字段继续保留。

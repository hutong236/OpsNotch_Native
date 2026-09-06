# Proposal: Desktop 命令避免抢占统一搜索

## 背景
#29 / v2.5.2 使用 `d1/d2/...` 与 query 防抖自动执行桌面切换，`d / desktop / 桌面` 也会自动打开桌面列表。该方式会与 Ops Notch 的统一搜索语义冲突，用户输入 `ddd`、`docker`、`desktop app` 时可能在输入过程中被 Desktop 功能抢占。

## 目标
- Desktop 命令改为搜索候选，不再监听 query 自动执行。
- 使用有空格的明确格式：`d 1`、`d 2`、`d 3`。
- `d` / `desktop` / `桌面` 只生成“查看桌面”候选，不自动弹出列表。
- 只有 Enter 或点击候选后才真正执行桌面动作。
- `d1/d2`、`ddd`、`docker` 等恢复为普通搜索。

## 非目标
- 不修改 #29 已实现的 Space 拓扑读取、Dock gesture、HID fallback、鼠标及焦点恢复。
- 不增加新的全局快捷键。

## 关联
- GitHub Issue #31
- Follow-up of #29

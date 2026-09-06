# Proposal: 快速桌面跳转

## 背景
Ops Notch 已经把 Finder、剪贴板和应用查找统一到同一个呼出入口。用户在多 Desktop/Space 工作时仍需要记忆系统切桌面快捷键，且跨显示器后鼠标与操作焦点不会自然跟随。

## 目标
- 在统一搜索框中输入 `d1`、`d2`、`d3` 等命令直接跳转到指定 macOS Desktop/Space。
- 输入 `d`、`desktop` 或 `桌面` 时展示当前全部可切换桌面。
- 切换时同步目标显示器、鼠标位置和窗口焦点。
- 不要求关闭 SIP，不要求用户配置 Control+数字快捷键。

## 非目标
- 不创建、删除或重新排序 Mission Control Space。
- 不移动用户窗口到其他 Space。
- 不增加新的全局快捷键。

## 关联
- GitHub Issue #29

# Design: Desktop 命令候选化

## 交互原则
搜索框始终优先允许用户继续输入。Desktop 解析只决定是否生成候选，不直接执行系统动作。

## 解析规则

```text
d            -> list 候选
desktop      -> list 候选
桌面          -> list 候选

d 1          -> switchTo(1) 候选
d 2          -> switchTo(2) 候选
desktop 3    -> switchTo(3) 候选
桌面 4        -> switchTo(4) 候选
```

以下内容不是命令：

```text
d1
d2
ddd
docker
desktop app
```

## 数据流

```text
query
  -> DesktopCommandParser
  -> visibleDesktopEntries
  -> QuickShelfEntry.desktop
  -> 统一键盘高亮 / 鼠标点击
  -> Enter / Click
  -> requestDesktopCommand
  -> DesktopCommandIntegration
  -> DesktopSpaceController
```

## 设计决策
- Desktop 候选排在统一结果列表顶部。
- Desktop 候选参与现有 `visibleQuickEntries`，复用方向键和 Enter 行为。
- `DesktopCommandIntegration` 不再订阅 `model.$query`，彻底移除 debounce 自动执行。
- Space 切换底层保持 #29 实现不变。

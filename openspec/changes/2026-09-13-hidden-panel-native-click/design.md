# 设计

- SwiftUI 保持面板内容；AppKit bridge 区分左右键，Control-click 视为右键。
- 在后台队列读取目标 AX 元素的实时 PID 和几何，匹配唯一的同进程 status-window 元数据。隐藏窗口也在 optionAll 内；不读取屏幕像素，不使用缓存坐标进行全局点击。
- 事件同时携带屏幕坐标和窗口内坐标，后者显式设置，避免跨进程转换丢失。
- 无动画结束面板，再在下一主队列周期重验窗口编号和进程，按最新位置发送 down/up 到指定 PID。清除修饰键，避免 Command 被解释为拖动。
- 定向窗口字段 0x33 和动态解析的 CGEventSetWindowLocation 是 AppKit 兼容性细节；缺少符号时停止投递，隔离在 MenuBarItemClickForwarder，并通过 macOS 探针检测。不得把成功投递声称为第三方应用已响应。
- 不使用全局事件投递、移动鼠标、修改第三方图标排列、展开 spacer 或重复 AX 回退。左右键语义不交叉回退。
- 权限在点击前复验。窗口失效或匹配不唯一时保留面板并提示刷新。操作期间忽略重复点击；设置、屏幕、可见状态或刷新变化会使待投递操作失效。
- CI 的菜单栏服务在创建 NSStatusItem 时不响应，因此探针使用自身离屏 AppKit 窗口，验证真实左右键接收、原生菜单进入 tracking、目标隔离和几何/鼠标不变，并检测没有本进程 NSWindow 对象的目标坐标编码。真实状态项、微信等第三方 App 及多屏刘海行为仍需实机验收。

本环境没有 OpenSpec CLI，按仓库 spec-driven 文件结构维护 proposal/design/specs/tasks；不修改仓库工具或规则。

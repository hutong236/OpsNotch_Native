# 设计

- 保留 AX 窗口编号及公共 CGWindow 描述的快速路径；匹配失败后查询 `CGSGetProcessMenuBarWindowList` / `SLSGetProcessMenuBarWindowList`。
- 通过动态解析的 WindowServer 导出函数读取窗口 owner connection、PID、screen rect 和 level，不依赖公共描述再次出现该窗口。函数不可用时保留诊断，不阻止 app 启动。
- 没有 AX 窗口编号时，专用清单仍要求真实窗口 level 为 status-window（25）、同 PID、AX 矩形包含关系和唯一匹配；清单成员身份不能使普通 layer 0 窗口获得点击资格。已有 AX 编号仍采用原有身份校验。
- 目标保存查询来源；发送前通过同一来源读取最新 PID/矩形，防止刚定位到的隐藏项又被公共 API 拒绝。保持既有平移/尺寸变化检查。
- 全量窗口数作为专用清单容量参考，留有余量且有上限；截断或非法数量视为查询失败。无常驻轮询、无图标展开/移动操作。
- 诊断包含公共/专用清单数量、查询结果、同 PID 候选和与 AX 几何相符的其他 PID，避免前 8 项普通窗口掩盖信息。无标题、路径或截图。
- 用查询闭包测试完整 fallback 路径。回归中的隐藏窗口是明确构造的 fixture，不伪称来自用户实机。

参考接口：Ice `Ice/Bridging/Bridging.swift` 和 `Ice/Bridging/Shims/Private.swift`；NUIKit/CGSInternal 的 `CGSWindow.h`、`CGSConnection.h` 提供所有者/PID/窗口边界函数签名。实现独立编写，仅使用接口契约。

环境无 OpenSpec CLI，按仓库现有 spec-driven 文件结构维护。

## 1. Core 回归测试(确立数据层基线)

- [x] 1.1 在 `Tests/OpsNotchCoreTests/OpsNotchCoreTests.swift` 新增取消置顶持久化用例:置顶后调用 `setPinned(id:, pinned: false)`,重新 `load()` 断言 `pinned == false` 且 `ShelfLogic.grouped` 将其归入 Recent;`swift test` 通过(数据层修复前即应通过,作为基线)
- [x] 1.2 新增取消置顶后 TTL 资格用例:`setPinned(false)` 且 updatedAt 超过 `tempTTLHours` 后,`ShelfLogic.expiredIDs` 包含该条目(不再豁免);`swift test` 通过

## 2. 交互层修复(ShelfWindowController)

- [x] 2.1 按 design.md D1 修改 `scheduleHide` 的 work item:在原有 `!shelfHovered`、`editorDraft == nil` 守卫后,新增"鼠标仍在 `panel.frame` 内"(`panel.frame.contains(NSEvent.mouseLocation)`)与"菜单正在跟踪"(`NSApp.keyWindow?.level == .popUpMenu`)两个暂缓信号,任一成立则 `scheduleHide(delay: 0.35)` 续期,否则才 `panel.orderOut(nil)`;`swift build` 通过
- [x] 2.2 复查与 sensor `mouseExited`(0.5s)触发路径的协同:确认鼠标真正离开 shelf 区域后仍会收敛到隐藏、无死循环续期;`swift build && swift test` 全绿
- [x] 2.3 (D1 修复后真机验收复现,按 design D2/D5 追加)修复 `ShelfRootView.content` 过期行:两个 `ForEach` 合并为单个 `ForEach(Array(model.visibleItems.enumerated()), id: \.element.id)`,置顶/最近分区头按行下标内联渲染,消除 `LazyVStack` 跨 ForEach 复用同 id 旧 cell 导致的置顶后图标/菜单不刷新;`swift build && swift test && scripts/static_checks.py` 全绿

## 3. 静态检查与打包

- [x] 3.1 `python3 scripts/static_checks.py` 通过,确认未触碰 `registerForDraggedTypes`、`changeCount` 等受检 API 调用点
- [x] 3.2 `./scripts/build_app.sh` 成功产出 ad-hoc 签名的 .app

## 4. 真机验收(对应 specs/shelf-items 全部场景)

- [x] 4.1 用 `./script/build_and_run.sh` 启动打包后的 .app:对任一条目执行置顶,右键打开菜单并停留 >1 秒后点击"取消置顶"——菜单不消失、操作生效、条目回到 Recent 顶部(需求"取消置顶操作入口始终可用"场景 1/3)
- [x] 4.2 悬停条目行点击 pin.slash 按钮取消置顶,条目回到 Recent;随后再置顶/再取消置顶往返切换均即时生效,按钮图标随状态切换(需求"取消置顶操作入口始终可用"场景 2)
- [x] 4.3 取消置顶最后一个置顶条目后 Pinned 分区头消失;退出并重启应用,状态保持未置顶(需求"分区与排序""持久化"场景)
- [x] 4.4 几何盲区回归:在列表底部行上打开右键菜单点击"取消置顶"(菜单下探出面板 frame)同样生效;鼠标离开 shelf 面板后仍按原延时自动隐藏;临时条目取消置顶后按 TTL 正常过期(可用设置短 TTL 验证)。若悬停按钮路径仍复现问题,按 design.md D2 以实测现象修订设计后再最小修复

> 4.1–4.4 于 2026-08-30 由用户在真机验收确认通过(含两处根因修复:D1 隐藏竞态、D5 过期行复用)。

# Tasks: 2026-09-05-shelf-pin-and-sensor-dot

## 1. Core 模型与测试

- [x] 1.1 `Sources/OpsNotchCore/Models.swift` 的 `ShelfSettings` 新增 `shelfKeepOpen: Bool`（默认 false；`init()`、`CodingKeys`(`shelf_keep_open`)、`init(from:)` 三处同步，解码用 `decodeIfPresent ?? false`）。验证：`swift build` 通过。
- [x] 1.2 `Tests/OpsNotchCoreTests/OpsNotchCoreTests.swift` 新增测试：旧 JSON 缺 `shelf_keep_open` 解码为 false；encode/decode 往返保留 true/false。验证：`swift test` 全绿（含既有迁移测试不回归）。

## 2. 常驻模式的隐藏抑制

- [x] 2.1 `ShelfWindowController.swift`：`scheduleHide` 开头读 `model.settings.shelfKeepOpen` 为 true 直接 return；失 key 观察者在常驻时跳过 `hide()`。验证：`swift build` 通过，对照 design D2 逐条核对四类自动隐藏路径（悬停移出、Shelf 移出、peek 延迟、确认后延迟）均经汇聚点。
- [x] 2.2 `SensorManager.swift`：`onMouseExit` 常驻时跳过 `scheduleHide()`（保留 `cancelScheduledExpand`）。验证：`swift build` 通过。
- [x] 2.3 取消图钉路径：Shelf 内关闭常驻后调用一次 `hide()`；确认 Esc 的 `requestHide` 直达路径不被汇聚点拦截。验证：代码走查 + build。

## 3. 图钉 UI、设置与本地化

- [x] 3.1 `ShelfView.swift` 头部操作区加图钉开关（复用现有行内轻量按钮模式，**不用 SwiftUI `Button`**；激活 `pin.fill`+强调色，未激活 `pin` 弱化；tooltip 与条目级 pinned 区分）。点击经 `model.updateSettings` 切换 `shelfKeepOpen`。验证：build + 界面上开关状态与图标同步。
- [x] 3.2 `SettingsWindowController.swift` 通用组加 `settingRow` 镜像开关（`Binding(get:set:)` → `model.updateSettings`）。验证：build + 设置中切换与 Shelf 图钉状态即时一致。
- [x] 3.3 `Localization.swift` zh/en 词典同增 `keepShelfOpen` 等键（设置行标题、tooltip）。验证：`python3 scripts/static_checks.py` 通过 + 运行时切换语言两处文案均正确。

## 4. 启动展开

- [x] 4.1 `AppDelegate.swift` 传感器构建完成后，若 `settings.shelfKeepOpen` 为 true，按 `displayTarget` 策略选定屏幕调用 Shelf 展开路径（expanded 态）。验证：build + 手动启动一次确认（详见 7.2）。

## 5. 触发区指示点

- [x] 5.1 `SensorManager.swift` 的 `SensorView` 增加 `showsIndicator` 标志与普通 `draw(_:)`：白色 alpha≈0.4、直径≈5pt 圆点，水平居中、距下缘≈4pt；**不开 `wantsLayer`**。验证：`swift build` 通过 + 临时置位标志肉眼可见（随后由 5.2 驱动）。
- [x] 5.2 `ShelfWindowController` 暴露 `onVisibilityChange` 闭包与 `isShelfVisible`（show 立即回调、hide 在收起动画完成后回调）；`AppDelegate` 接线到 `SensorManager` 统一设置各传感器标志；传感器重建时用当前 `isShelfVisible` 初始化。验证：build + 手动验收 7.3。

## 6. 质量门

- [x] 6.1 `swift build`、`swift test`、`python3 scripts/static_checks.py` 全部通过；确认未触碰 `static_checks.py` 要求的 API 调用点与禁词。

## 7. 手动验收（用户实测，按 VERIFY_ON_MAC.md 补充执行；实测通过后再勾选）

- [x] 7.1 常驻行为：开启图钉后鼠标移出/切走应用失焦/拖放成功后 Shelf 均不收起；Esc 临时收起且常驻保留、再次悬停重展并保持；点击图钉取消即收起并恢复自动隐藏。
- [x] 7.2 持久化与兼容：开启常驻重启应用后 Shelf 直接展开；用升级前旧 `shelf.json` 启动正常加载、常驻默认关闭、行为同旧版；设置窗口镜像开关即时生效。
- [x] 7.3 指示点：收起时出现、展开/拖放/peek 时隐藏；多屏下仅 Shelf 所在屏隐藏；拔插显示器重建后状态正确；带刘海屏上点在刘海下缘可见、深浅色菜单栏均可辨识；悬停与拖放交互与无点时一致；展开/收起切换无闪烁。
- [x] 7.4 中英文界面下新增文案（图钉 tooltip、设置行）均正确显示。

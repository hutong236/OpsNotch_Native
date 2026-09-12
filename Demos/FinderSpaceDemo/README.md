# Finder 跨显示器 / 桌面移动 Demo 0.2

这个独立 App 用来定位 Ops Notch v2.7.19 中窗口跨桌面移动失败的原因。它直接按 `com.apple.finder` 查找 Finder，列出普通窗口供选择，移动时固定该窗口的 ID；不使用 Ops Notch 的快捷键、Quick Shelf、桌面菜单和焦点恢复流程。0.2 增加跨显示器测试：先放置窗口到目标屏的可见区域，再移动到指定普通桌面。**这是待真机验收的诊断版本，不代表生产工具已支持跨屏。**

## 运行

下载该 PR 的 CI Artifact `FinderSpaceDemo-macOS`，解压其中的 `FinderSpaceDemo-macOS.zip`，把 `FinderSpaceDemo.app` 放到“应用程序”后打开。此测试包与现有发布包一样采用 ad-hoc 签名；首次打开如被系统拦截，可在“系统设置 → 隐私与安全性”中允许打开。

从源码运行（需要 macOS + Xcode Command Line Tools）：

```bash
./script/finder_space_demo.sh
```

只构建：`./script/finder_space_demo.sh --build-only`。

## 测试步骤（macOS 26.6.2）

1. 先退出 Ops Notch，排除它的菜单和焦点恢复行为。退出前保存好正在进行的拖放操作。
2. 在源显示器打开一个普通 Finder 文件夹窗口。窗口不要全屏或最小化，Finder 不要设置为“分配到所有桌面”。同屏测试准备两个普通桌面；跨屏测试使用扩展显示，开启“系统设置 → 桌面与程序坞 → 调度中心 → 显示器具有单独的空间”，并按系统提示重新登录。目标显示器当前也应显示普通桌面。
3. 打开 Demo，点击“辅助功能权限”，在系统设置中允许 **FinderSpaceDemo**。它和 Ops Notch 是两个不同 App，需要分别授权。返回后点击“刷新窗口与桌面”；如果系统尚未生效，退出并重新打开 Demo。
4. 选择刚才的 Finder 窗口和目标项，例如“显示器 2：外接显示器 · 桌面 2 · Space 93”。桌面序号从每台显示器的 1 开始；Space 93 是内部 ID，不是桌面 93。显示器编号用于区分名称相同的两块屏。
5. 保持“Objective-C 直接调用”和“移动前激活 Finder”，点击“移动所选 Finder 窗口”。不用按 ⌥ / ⇧。
6. 查看结果后，手动到目标显示器的目标桌面检查：原窗口已经离开源屏/源桌面，并完整出现在目标屏/目标桌面。跨屏时保持窗口的点尺寸；目标屏较小时按需缩小，避开菜单栏和 Dock。Demo 不自动跟随。
7. 如果成功，选择桌面 1 移回，再改为“Swift 调用（对照 v2.7.19）”重复测试。
8. 如果需要分辨焦点因素，可移回后取消“移动前激活 Finder”，再测相同调用方式。
9. 点击“复制诊断日志”或“保存诊断日志…”，返回操作结果和日志。日志只保存在本机，不会自动上传；不记录 Finder 窗口标题或文件夹路径。

Demo 每次移动一个明确选定的 Finder 窗口。原本已在目标桌面、全屏、最小化或同时属于多个 Space 时会明确拒绝。镜像屏和多显示器共享 Spaces 不支持按“显示器 + 独立桌面”测试；目标显示器当前为全屏或 Split View 时需先切回普通桌面。

跨屏分两组测试，区别非常关键：

| 场景 | 需要检查 |
| --- | --- |
| 显示器 A → 显示器 B 当前桌面（目标项带 ✓） | AX 跨屏放置可能已完成整个移动。出现 `SPACE_CALL_SKIPPED` 是预期，但不能证明私有 Space API 有效 |
| 显示器 A → 显示器 B 非当前桌面（目标项不带 ✓） | 应先出现 `DISPLAY_STAGED`，再出现 `CALL` / `SUBMITTED`，最后 `VERIFIED`；同时目视确认指定桌面 |
| 显示器 B → 显示器 A | 验证反向坐标；可覆盖左侧或上方显示器的负坐标 |
| 同显示器桌面 1 → 桌面 2 | 保留原有两种调用方式的回归对照 |

**部分失败会保留现场：** 如果窗口已进入目标屏当前桌面，但未进入指定的另一个桌面，Demo 会显示未完成，输出 `TIMEOUT` 或 `FAILED_STATE`，不会自动把窗口搬回。查看实际位置后刷新，可以明确选择源桌面移回。测试过程中插拔/重新排列显示器会中止动作，请刷新后再测。

## 如何看结果

| 记录 | 含义 |
| --- | --- |
| `AX_TRUSTED false` / `FINDER_AX_WINDOWS_FAILED` | Finder 窗口读取或权限阶段失败，还没调用移动接口 |
| `BRIDGE missing-…` | 找不到某个接口或 Objective-C 方法 |
| `BEFORE … spaces=[源ID] target=目标ID` | 已固定需要移动的 Finder 窗口 |
| `DISPLAY` / `CROSS_DISPLAY_PLAN` | 源和目标屏 UUID、全局点坐标、可见区域、缩放比例及计划窗口位置 |
| `RESIZE` / `POSITION` / `STAGING` | AX 调整窗口大小和跨屏位置，记录每一步结果 |
| `DISPLAY_STAGED` | 窗口已完整进入目标屏的一个普通桌面；还不代表指定桌面移动成功 |
| `SPACE_CALL_SKIPPED` | AX 放置已进入目标屏当前桌面，本次未调用私有 Space API |
| `CALL method=…` / `SUBMITTED raw_result=…` | 只说明提交了请求；返回值不当成成功标志 |
| `GEOMETRY … fits=true` | 已读取实际 AX 窗口位置，并确认完整位于目标屏可见区域 |
| `VERIFIED … before=[源ID] after=[目标ID] cross_display=true` | 连续 3 次同时确认唯一目标 Space 和目标屏内窗口位置；还需目视确认 |
| `TIMEOUT` / `FAILED_STATE` | 未完成指定移动，记录最终 Space 归属和已知窗口位置 |

自动日志在 `~/Library/Logs/lab.hutong.opsnotch.finder-space-demo/`。如果发生闪退，取该目录最新日志和 macOS 的 FinderSpaceDemo 崩溃报告，重点看最后一条是否是 `CALL`。

## 对照工具时的判断

| Demo 结果 | 下一步定位 |
| --- | --- |
| Objective-C 成功，Swift 失败 | 优先检查现有 Swift 到 Objective-C 的调用桥接 |
| 两种调用均成功，Ops Notch 失败 | 优先检查原窗口捕获时机、NSMenu 修饰键动作是否真正触发、隐藏后的焦点恢复 |
| 仅“先激活 Finder”成功 | 检查前台状态和窗口重新激活顺序 |
| 两种调用均 `TIMEOUT` | 系统没有确认移动；不继续宣称私有 API 可用，依据日志排查系统接口/窗口归属 |

这些是诊断分支，不能仅靠代码阅读确定最终根因。

## CI 验证范围

CI 执行 7 项显示器几何单元测试，覆盖负坐标、上下/左右排列、Dock 可见区域、保持点尺寸、过大窗口、完整落屏及非法几何；然后构建并签名 Demo，还执行 `--probe`：创建 **Demo 自己的临时窗口**，分别通过 Objective-C / Swift 将它提交到其**当前 Space**，检查调用是否正常返回和窗口归属是否异常变化。此处会真正执行入口，而不只是检查符号存在。

**该探针不移动 Finder，也不证明跨桌面或跨显示器移动成功。** 日志必须明确包含 `CROSS_SPACE_NOT_TESTED; CROSS_DISPLAY_NOT_TESTED; FINDER_NOT_TESTED`。Finder 跨屏及跨桌面验收必须用以上 GUI 步骤在用户的 Mac 完成。

Objective-C 对照路径参考 [yabai 的 Space 移动调用](https://github.com/asmvik/yabai/blob/dd845723416f5fe92af49fad5ebab00369e07edd/src/space_manager.c)。Demo 复用仓库的 Mach-O 符号解析器，但窗口查找和动作入口独立于生产 App。

## English quick start

Run `./script/finder_space_demo.sh` on macOS, or download the CI app artifact. Enable Accessibility for **FinderSpaceDemo**, open a normal Finder window, then Refresh. Choose a display and a normal desktop; click Move. Use extended displays with **Displays have separate Spaces** enabled for cross-display tests. First test the destination monitor's visible desktop, then a non-visible desktop, then the reverse direction. The window is placed inside the destination's visible frame before requesting the final Space. `VERIFIED` requires three consecutive readings of both the sole destination Space and, for cross-display transfers, the complete window fitting on that display. `SPACE_CALL_SKIPPED` means AX placement already reached the destination's visible desktop; the private Space API was not exercised. Partial failures leave the window where it reached and log its state; refresh to move it back. CI tests geometry and same-Space invocation on the demo's own window, not real Finder cross-display movement.

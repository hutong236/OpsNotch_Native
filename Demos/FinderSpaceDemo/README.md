# Finder 桌面移动 Demo

这个独立 App 用来定位 Ops Notch v2.7.19 中窗口跨桌面移动失败的原因。它直接按 `com.apple.finder` 查找 Finder，列出普通窗口供选择，移动时固定该窗口的 ID；不使用 Ops Notch 的快捷键、Quick Shelf、桌面菜单和焦点恢复流程。

## 运行

下载该 PR 的 CI Artifact `FinderSpaceDemo-macOS`，解压其中的 `FinderSpaceDemo-macOS.zip`，把 `FinderSpaceDemo.app` 放到“应用程序”后打开。此测试包与现有发布包一样采用 ad-hoc 签名；首次打开如被系统拦截，可在“系统设置 → 隐私与安全性”中允许打开。

从源码运行（需要 macOS + Xcode Command Line Tools）：

```bash
./script/finder_space_demo.sh
```

只构建：`./script/finder_space_demo.sh --build-only`。

## 测试步骤（macOS 26.6.2）

1. 先退出 Ops Notch，排除它的菜单和焦点恢复行为。退出前保存好正在进行的拖放操作。
2. 在同一显示器准备两个普通桌面。在桌面 1 打开一个普通 Finder 文件夹窗口。窗口不要全屏或最小化，Finder 不要设置为“分配到所有桌面”。
3. 打开 Demo，点击“辅助功能权限”，在系统设置中允许 **FinderSpaceDemo**。它和 Ops Notch 是两个不同 App，需要分别授权。返回后点击“刷新窗口与桌面”；如果系统尚未生效，退出并重新打开 Demo。
4. 选择刚才的 Finder 窗口和桌面 2。界面同时显示真实 Window ID / Space ID，桌面按显示器分组命名。
5. 保持“Objective-C 直接调用”和“移动前激活 Finder”，点击“移动所选 Finder 窗口”。不用按 ⌥ / ⇧。
6. 查看结果后手动切到桌面 2，确认原窗口消失于桌面 1、出现在桌面 2。Demo 不自动跟随，也不会用切桌面冒充移动窗口。
7. 如果成功，选择桌面 1 移回，再改为“Swift 调用（对照 v2.7.19）”重复测试。
8. 如果需要分辨焦点因素，可移回后取消“移动前激活 Finder”，再测相同调用方式。
9. 点击“复制诊断日志”或“保存诊断日志…”，返回操作结果和日志。日志只保存在本机，不会自动上传；不记录 Finder 窗口标题或文件夹路径。

当前 Demo 只验同一显示器中的两个普通桌面，每次移动一个明确选定的 Finder 窗口。移动到当前桌面、全屏、最小化或同时属于多个 Space 时会明确拒绝，避免误判成功。

## 如何看结果

| 记录 | 含义 |
| --- | --- |
| `AX_TRUSTED false` / `FINDER_AX_WINDOWS_FAILED` | Finder 窗口读取或权限阶段失败，还没调用移动接口 |
| `BRIDGE missing-…` | 找不到某个接口或 Objective-C 方法 |
| `BEFORE … spaces=[源ID] target=目标ID` | 已固定需要移动的 Finder 窗口 |
| `CALL method=…` / `SUBMITTED raw_result=…` | 只说明提交了请求；返回值不当成成功标志 |
| `VERIFIED … before=[源ID] after=[目标ID]` | 连续 3 次读取确认只属于目标 Space，原 Space 已不包含此窗口；还需目视确认 |
| `TIMEOUT …` | 5 秒内未确认移动；保留最终 Space 归属，便于判断静默无效 |

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

CI 构建并签名 Demo，还执行 `--probe`：创建 **Demo 自己的临时窗口**，分别通过 Objective-C / Swift 将它提交到其**当前 Space**，检查调用是否正常返回和窗口归属是否异常变化。此处会真正执行入口，而不只是检查符号存在。

**该探针不移动 Finder，也不证明跨桌面移动成功。** 日志必须明确包含 `CROSS_SPACE_NOT_TESTED; FINDER_NOT_TESTED`。Finder 跨桌面验收必须用以上 GUI 步骤在用户的 Mac 完成。

Objective-C 对照路径参考 [yabai 的 Space 移动调用](https://github.com/asmvik/yabai/blob/dd845723416f5fe92af49fad5ebab00369e07edd/src/space_manager.c)。Demo 复用仓库的 Mach-O 符号解析器，但窗口查找和动作入口独立于生产 App。

## English quick start

Run `./script/finder_space_demo.sh` on macOS, or download the CI app artifact. Enable Accessibility for **FinderSpaceDemo**, open a normal Finder folder window, then Refresh. Select its window and a different normal desktop on the same display; click Move. Switch desktops manually to inspect the result. Compare the Objective-C and Swift methods, then copy the log. `VERIFIED` requires three consecutive membership readings containing only the target Space. The CI probe tests invocation on the demo's own window in its current Space; it does not validate Finder movement across Spaces.

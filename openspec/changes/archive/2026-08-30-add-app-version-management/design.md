## Context

- 版本号目前只在仓库根 `Info.plist`（`CFBundleShortVersionString: 2.0.1`，`CFBundleVersion: 201`）中维护；两个打包脚本把它原样拷贝进产物，没有任何注入或校验逻辑（见 `scripts/build_app.sh:20`、`script/build_and_run.sh:21`）。
- Swift 代码中不存在应用版本读取逻辑；`ShelfStore.version` 是存储格式版本，与应用版本无关，本变更不触碰。
- `StatusBarController.rebuildMenu()` 已支持按 `model.language` 重建菜单；`SettingsView` 是 SwiftUI 内容视图，底部目前没有 about 区域。
- 架构约束：AppKit 负责系统交互，SwiftUI 只做内容；Core 保持无 AppKit 依赖。版本读取属于系统层（读取 Bundle），放在 OpsNotchApp。

## Goals / Non-Goals

**Goals:**
- 版本号有单一权威来源（Bundle 的 `CFBundleShortVersionString`），代码不重复维护。
- 打包脚本可注入版本号，CI 与本地打包行为一致。
- 状态栏菜单与设置窗口展示版本，支持 zh/en 切换。

**Non-Goals:**
- 不做自动检查更新、更新下载、Sparkle 等更新机制。
- 不做 `CFBundleVersion`（build number）的独立管理策略，只按规则从 `CFBundleShortVersionString` 派生。
- 不改动 `shelf.json` 存储格式版本（`ShelfStore.version`）。
- 不新增 Info.plist 的额外键（如 copyright、开发者信息展示）。

## Decisions

1. **版本读取：`AppVersionService`（OpsNotchApp，`@MainActor` 无状态枚举/struct）读取 `Bundle.main`**
   - 用 `Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String`，空/缺失时回退 `"0.0.0-dev"`。
   - 放在 OpsNotchApp 而非 Core：读取 Bundle 属于系统层行为，Core 必须保持无 AppKit/Bundle 依赖以便纯单元测试。服务本身足够薄，不需要 Core 抽象。
   - 备选：编译期用 `swift build -c` 自定义 flag 注入版本字面量 —— 弃用，因为 SPM 传入 define 需要改 Package.swift 且让每次构建的哈希变化，还要处理脚本传参，复杂度不匹配收益。
   - 备选：读 `Bundle.main.infoDictionary` 整个字典 —— 等价，取单个 key 更直接。

2. **构建注入：脚本用 `/usr/libexec/PlistBuddy` 写产物 Info.plist，不动仓库根 Info.plist**
   - `scripts/build_app.sh` 与 `script/build_and_run.sh` 在拷贝 `Info.plist` 后，若设置了 `APP_VERSION` 环境变量，则 `PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION"`，并把 `CFBundleVersion` 设为 `APP_VERSION` 去掉 `.` 后的数字（`2.1.0` → `210`）；未设置时零改动。
   - 不改根 `Info.plist`：脚本注入只影响产物，仓库默认值仍是唯一手工维护点，避免脚本写源文件造成 git 脏状态。
   - 备选：用 `plutil -replace` —— 功能等价，PlistBuddy 在两个脚本语境下都更常见，二选一均可，取 PlistBuddy。
   - 校验：`APP_VERSION` 需匹配 `^[0-9]+\.[0-9]+\.[0-9]+$`，不匹配时报错退出，避免写入垃圾值。

3. **状态栏菜单：在"打开货架/新建文本"组后加一条禁用信息项**
   - `NSMenuItem(title: "Ops Notch v\(AppVersionService.current)")`，`isEnabled = false`（`action` 为 nil 即不可点击）。放在设置项之前的分隔区内。
   - 文案不需要进 L10n 字典 —— "Ops Notch" 是产品名，两种语言下展示一致；菜单其余项本就走 `L10n.text`，`rebuildMenu()` 已随语言切换重建，无需新增刷新逻辑。
   - 若仍需本地化前缀（如"版本"），加 `version` key 进 zh/en 字典 —— 默认采用 "Ops Notch vX.Y.Z" 无需翻译，保持简单。

4. **设置窗口：`SettingsView` 底部加 about 行**
   - 在 `VStack` 尾部加一个小号灰色文本行：`Ops Notch v\(AppVersionService.current)`，直接引用同一服务，天然与菜单一致。
   - 文本 key 不新增（产品名 + 版本号无翻译需求）。

5. **测试范围：仅 Core 有 XCTest，本变更的可测逻辑在 App 层**
   - 版本字符串派生（`2.1.0` → `210`）逻辑很短，直接内联在 shell 中，不为它引入 Core 类型或测试；手动验收按 `VERIFY_ON_MAC.md` 流程覆盖 UI 展示项。
   - `static_checks.py` 的必备 API 调用点与本变更不冲突，不改 checker。

## Risks / Trade-offs

- [脚本注入与根 Info.plist 版本不一致，出现"多版本号来源"] → 根 Info.plist 仍是默认值，注入仅显式发生；CI/release 流程只在需要发版时传 `APP_VERSION`，规则写进脚本注释。
- [`CFBundleVersion` 派生规则对预发布号（`2.1.0-beta`）不适用] → 校验正则只接受三段数字，预发布号需直接改根 `Info.plist`，脚本报错提示。
- [`swift run` 下显示 `0.0.0-dev` 可能被误认为 bug] → 符合规格的后备行为；`swift run` 本就不产生正确 bundle 行为（见 AGENTS.md gotchas），UI 正常不崩溃即可。

## Migration Plan

无数据迁移。发版流程变为：改根 `Info.plist`（或打包时传 `APP_VERSION`）→ 打包。回滚即还原提交。

## Open Questions

（无 — 版本展示位置与注入方式已按上文确定，若用户希望调整展示位置或格式，在 review 时提出即可。）

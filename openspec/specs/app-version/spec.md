# app-version Specification

## Purpose

为应用提供统一的版本号管理与展示能力：版本号有单一权威来源，构建时可注入，并在状态栏菜单与设置窗口中向用户展示当前版本。

## Requirements

### Requirement: 版本号单一来源
应用版本号 SHALL 以打包产物 `Info.plist` 中的 `CFBundleShortVersionString` 为唯一权威来源。运行时代码 SHALL 通过读取应用 Bundle 的该字段获取版本号，MUST NOT 在 Swift 源码中维护第二份硬编码版本字符串。当代码不在应用 Bundle 中运行（如 `swift run`/单元测试）时，SHALL 返回非空的后备值（如 "0.0.0-dev"）而非崩溃。

#### Scenario: 从 Bundle 读取版本
- **WHEN** 应用以打包的 .app 形式启动
- **THEN** 运行时获取的版本号等于该 Bundle 的 `Info.plist` 中 `CFBundleShortVersionString` 的值

#### Scenario: 无 Bundle 时的后备行为
- **WHEN** 进程没有有效的应用 Bundle（如 `swift run` 直接运行）
- **THEN** 版本读取返回非空后备值，界面与菜单正常展示，不崩溃

### Requirement: 构建脚本注入版本号
打包脚本（`scripts/build_app.sh`、`script/build_and_run.sh`）SHALL 支持通过环境变量 `APP_VERSION` 覆盖写入产物 `Info.plist` 的 `CFBundleShortVersionString`（`CFBundleVersion` 同步为去掉点号的数字形式）。未设置 `APP_VERSION` 时，SHALL 保留仓库根 `Info.plist` 中的默认值。

#### Scenario: 通过环境变量注入版本
- **WHEN** 以 `APP_VERSION=2.1.0` 执行打包脚本
- **THEN** 产物 .app 的 `Info.plist` 中 `CFBundleShortVersionString` 为 `2.1.0`，`CFBundleVersion` 为 `210`

#### Scenario: 默认版本
- **WHEN** 不设置 `APP_VERSION` 执行打包脚本
- **THEN** 产物 .app 的 `Info.plist` 中的版本号与仓库根 `Info.plist` 一致

### Requirement: 状态栏菜单展示版本
状态栏菜单 SHALL 包含一条展示当前版本的信息项（格式如 "Ops Notch v<版本号>"）。该信息项 MUST NOT 响应点击操作（无 action、不触发任何行为）。菜单 SHALL 支持中英文运行时切换，版本项文本随语言设置刷新。

#### Scenario: 菜单显示版本
- **WHEN** 用户打开状态栏菜单
- **THEN** 菜单中可见 "Ops Notch v<当前版本>" 的不可点击信息项

#### Scenario: 语言切换后刷新
- **WHEN** 用户在设置中把语言从中文切换为英文后再次打开状态栏菜单
- **THEN** 版本信息项按新语言渲染（版本号本身不变）

### Requirement: 设置窗口展示版本
设置窗口 SHALL 在可见位置（窗口底部）展示 "应用名 + 版本号"。展示内容 SHALL 与 Bundle 中的 `CFBundleShortVersionString` 一致。

#### Scenario: 设置窗口显示版本
- **WHEN** 用户打开设置窗口
- **THEN** 窗口内可见应用名称与当前版本号，与状态栏菜单显示的版本号一致

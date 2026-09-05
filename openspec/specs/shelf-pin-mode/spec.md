# shelf-pin-mode Specification

## Purpose

为 Shelf 提供"常驻展开"工作模式:用户可通过图钉开关让 Shelf 保持展开、不被任何自动隐藏逻辑收起,状态跨启动持久化;保留显式隐藏途径(Esc、取消图钉),保证用户始终拥有最终控制权。

## Requirements

### Requirement: Shelf 内图钉开关

Shelf 展开时 SHALL 提供一个图钉开关,用于切换常驻展开状态。该开关在视觉与语义上 MUST 与条目级"固定(pinned)"明确区分,避免混淆。

#### Scenario: 开启常驻

- **WHEN** Shelf 展开且用户点击图钉开关
- **THEN** Shelf 进入常驻状态,开关图标呈现"已钉住"样式,且 Shelf 不因本次切换而收起

#### Scenario: 取消常驻

- **WHEN** Shelf 处于常驻状态且用户再次点击图钉开关
- **THEN** Shelf 退出常驻状态并收起

### Requirement: 常驻期间抑制全部自动隐藏

当常驻开启时,系统 MUST NOT 通过任何自动路径隐藏 Shelf,包括:鼠标移出触发区、鼠标移出 Shelf、拖放成功后的 peek 延迟、Shelf 失去键盘焦点、编辑确认后的延迟隐藏。

#### Scenario: 鼠标移出不收起

- **WHEN** Shelf 常驻且鼠标从触发区或 Shelf 上移开
- **THEN** Shelf 保持展开

#### Scenario: 失去焦点不收起

- **WHEN** Shelf 常驻且 Shelf 窗口失去键盘焦点(用户切换到其他应用)
- **THEN** Shelf 保持展开

#### Scenario: 拖放后不收起

- **WHEN** Shelf 常驻且用户向 Shelf 拖放物品成功
- **THEN** Shelf 在成功提示后保持展开

### Requirement: 显式隐藏途径保留

常驻开启时,用户显式的隐藏操作 MUST 仍然生效:按 Esc 收起 Shelf(常驻状态保留,下次悬停重新展开并保持);点击图钉取消常驻并收起。

#### Scenario: Esc 临时收起

- **WHEN** Shelf 常驻且用户按下 Esc
- **THEN** Shelf 收起,常驻状态仍为开启;随后鼠标再次进入触发区时 Shelf 重新展开并保持

#### Scenario: 图钉取消并收起

- **WHEN** Shelf 常驻且用户点击图钉开关取消常驻
- **THEN** Shelf 退出常驻并恢复默认自动隐藏行为(移出后延时收起)

### Requirement: 常驻状态持久化与启动展开

常驻状态 SHALL 持久化到 `shelf.json` 的设置中,并跨应用重启保留。旧数据缺失该字段时 MUST 默认为关闭(即保持现有自动隐藏行为),不得破坏旧文件加载。

#### Scenario: 重启恢复

- **WHEN** 用户开启常驻后退出并重新启动应用
- **THEN** 常驻状态仍为开启,且 Shelf 按显示目标策略直接展开

#### Scenario: 旧数据默认关闭

- **WHEN** 旧版 `shelf.json` 中不存在常驻字段
- **THEN** 应用正常加载,常驻默认关闭,行为与升级前一致

### Requirement: 设置窗口镜像开关

设置窗口 SHALL 提供与 Shelf 图钉等价的常驻开关,二者操作同一状态并即时生效。

#### Scenario: 设置中切换即时生效

- **WHEN** 用户在设置窗口切换常驻开关
- **THEN** Shelf 的常驻状态立即同步(开启且 Shelf 可见时不收起;关闭且无其他保持条件时按默认延时收起)

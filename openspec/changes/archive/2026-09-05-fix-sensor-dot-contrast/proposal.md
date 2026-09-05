# Proposal: 触发区指示点对比度修复 (2026-09-05-fix-sensor-dot-contrast)

## Why

`2026-09-05-shelf-pin-and-sensor-dot` 的指示点已按安全区定位并确认**能画出来、位置正确**(用户复测"隐约可见"),但白色 40% 透明度叠加在半透明菜单栏背景上对比度过低,起不到入口提示作用——不满足 sensor-indicator 规格中"半透明可辨识"的要求。本次修复使实现与该既有需求对齐,不改变任何需求语义。

## What Changes

- 重设计指示点绘制:由单层"白色 4pt/40%"改为**双层圆点**——加一圈细的深色描边环,内核提高不透明度,使其在明色/暗色菜单栏与任意壁纸上均可辨识。
- 尺寸小幅上调(总 footprint 约 6~7pt),保持"小而不喧宾夺主"。
- 不改指示点的显示时机(仅收起时)、定位算法(按 `safeAreaInsets` 避刘海)、事件驱动机制与交互语义。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

（无——"收起时显示、可辨识、不遮挡、不闪烁"的行为契约已由进行中变更 `2026-09-05-shelf-pin-and-sensor-dot` 的 `sensor-indicator` delta 持有,本次仅让实现达到该契约,无需求文本变化,故声明 `skip_specs`。）

## Impact

- `Sources/OpsNotchApp/SensorManager.swift`:仅 `SensorView.draw(_:)` 与相关常量(约 10 行);不动窗口/事件/可见性联动代码。
- 无数据格式、无 API、无本地化变化;`static_checks.py` 要求的调用点不受影响。
- 验证依赖真机目测(明/暗菜单栏、深/浅壁纸),按 VERIFY_ON_MAC.md 执行。

# Tasks: 2026-09-05-fix-sensor-dot-contrast

## 1. 绘制改造

- [x] 1.1 `Sources/OpsNotchApp/SensorManager.swift` 的 `SensorView`:新增文件私有 `DotStyle` 常量组(core 4pt/alpha 0.85,ring 外径 6.5pt/alpha 0.35),`draw(_:)` 改为先画深色描边环、再画白色内核;定位继续用 `indicatorDotCenter`,不开 `wantsLayer`。验证:`swift build` 通过。

## 2. 质量门

- [x] 2.1 `swift build`、`swift test`、`python3 scripts/static_checks.py` 全绿;确认未触碰 `static_checks.py` 要求的调用点与禁词。验证:三条命令输出。

## 3. 手动验收(用户实测,通过后再勾选)

- [x] 3.1 打包启动后,Shelf 收起时指示点在浅色壁纸/亮色菜单栏与深色壁纸上均清晰可辨但不刺眼;Shelf 展开时消失;位置仍在刘海下方可见带(或旁侧),无锯齿感明显劣化。验证:按 VERIFY_ON_MAC.md 目测;若浓淡需微调,只动 `DotStyle` 常量。

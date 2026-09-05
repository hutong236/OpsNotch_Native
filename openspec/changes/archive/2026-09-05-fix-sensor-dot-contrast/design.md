# Design: 2026-09-05-fix-sensor-dot-contrast

## Context

- 用户复测结论:"隐约可见但太淡"——说明 `SensorView.draw(_:)` 管线正常、按 `safeAreaInsets` 的避刘海定位正确,唯一问题是对比度:单层白 40% alpha 压在半透明菜单栏(壁纸透传,可能偏亮)上几乎融进背景。
- 绘制处只有一处:`SensorView.draw(_:)`(SensorManager.swift),普通非 layer 视图(项目规定不开 `wantsLayer`)。
- 约束:点须在明/暗菜单栏、深/浅壁纸上都可辨识;同时"小而不喧宾夺主、不闪烁"(sensor-indicator 规格)。

## Goals / Non-Goals

**Goals:**

- 任意背景下均可辨识的双层圆点,总 footprint 约 6~7pt。
- 改动收敛在 draw 函数与常量,无结构变化。

**Non-Goals:**

- 不改显示时机、定位算法、事件联动;不加动画;不引入自适应外观取色;不处理 Shelf 图钉(用户确认无问题)。

## Decisions

### D1. 双层圆点:深色描边环 + 高不透明度白色内核

- 外环:直径约 6.5pt,`NSColor.black.withAlphaComponent(0.35)`;内核:直径约 4pt,`NSColor.white.withAlphaComponent(0.85)`。
- 理由:深色环保证亮背景上轮廓清晰,白色内核保证暗背景(含黑色刘海边缘带)上足够醒目——双层组合对背景明暗不敏感,无需取色。备选:单纯提高 alpha 到 0.7——亮壁纸上白点依旧发虚,否;用 `labelColor` 自适应——菜单栏外观与应用外观可能不一致且依赖绘制时 `NSAppearance.current`,不确定性高,否。

### D2. 常量集中在 `SensorView` 文件私有 `enum DotStyle`,便于复测微调

`coreDiameter / ringOuterDiameter / coreAlpha / ringAlpha` 四个常量,手动验收若需微调只动一处。备选:硬编码散在 draw 里——后续调参易漏,否。

### D3. 定位沿用现有 `indicatorDotCenter`,不改

"隐约可见"已证明位置正确;本变更不动 `SensorManager.indicatorDotCenter(for:)`。

## Risks / Trade-offs

- [环+核双层在低分屏边缘可能有轻微锯齿] → `NSBezierPath` 默认抗锯齿,6.5pt 尺寸下可接受;验收时目测。
- [0.85 内核在纯黑刘海边缘带上略刺眼] → footprint 仅 4pt,且位于收起态;验收时若嫌亮只调 `coreAlpha`。

## Migration Plan

无数据/格式变化;回滚即还原 draw 函数。

## Open Questions

无。

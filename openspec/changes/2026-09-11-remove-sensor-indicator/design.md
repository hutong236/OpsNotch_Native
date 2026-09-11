# Design

## Decision
`SensorView` remains a transparent native drag destination with its existing bounds, but draws no persistent affordance while idle.

## AppKit Structure Kept
- `NSPanel`
- `NSTrackingArea`
- `registerForDraggedTypes`
- `NSDraggingDestination`

## Removed
- `showsIndicator`
- `usesWideIndicator`
- `indicatorDotCenter`
- indicator style constants and `draw(_:)` implementation
- `SensorManager` indicator visibility bookkeeping and geometry helpers

## Compatibility
`SensorManager.setShelfVisible(_:onDisplayID:)` remains as a no-op compatibility hook so existing visibility callbacks do not require unrelated refactoring.

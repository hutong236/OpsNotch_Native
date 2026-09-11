# Design: drag-only top Sensor

## Goals
- Make ordinary pointer movement at the top edge completely inert with respect to Shelf visibility.
- Preserve the existing large native drag/drop target and Nearby drag assist.
- Remove the hover-intent state machine introduced for pointer activation.

## Approach

### SensorManager
Do not wire `onMouseEnter`, `onHoverIntent`, or `onMouseExit` callbacks. `setExternalDragSessionActive` remains only for coordinating Nearby mode with the top Drop UI.

### SensorView
Keep the native `NSDraggingDestination` behavior unchanged. A passive `NSTrackingArea` may remain as part of the Sensor's AppKit structure, but it has no mouse-enter/move/exit business callbacks and therefore cannot expand or hide the Shelf.

### Cleanup
Remove `HoverIntentPolicy` and its tests because ordinary pointer hover is no longer a supported interaction.

## Non-goals
- No changes to `draggingEntered`, `draggingUpdated`, `draggingExited`, `performDragOperation`, payload resolution, File Promise handling, Nearby overlay geometry, or Shelf content.

# Design: shelf hover intent guard

## Goals
- Reduce accidental Shelf expansion caused by ordinary menu-bar traversal.
- Preserve the large native Sensor surface used for drag/drop discoverability.
- Keep the decision logic deterministic and unit-testable outside AppKit.

## Approach

### Geometry split
`SensorGeometry` continues to size the real Sensor panel exactly as before. Drag/drop therefore keeps the full panel bounds. Ordinary mouse hover gets a separate 100×8pt tracking strip anchored at the bottom-center of the Sensor (the edge approached from the desktop below).

### Intent gate
`HoverIntentPolicy` lives in `OpsNotchCore` and decides two things:

1. whether the entry point is consistent with entering through the lower edge rather than crossing from the left/right menu-bar direction;
2. whether pointer travel remains within 6pt during the dwell.

`SensorView` translates AppKit points into this pure policy and owns only tracking/timer lifecycle.

### Dwell
A valid entry waits 0.4s before calling `onHoverIntent`. Leaving the strip, beginning a native drag, suppressing hover due to an external drag session, or moving farther than 6pt cancels the pending intent.

## Non-goals
- Do not change `draggingEntered`, `performDragOperation`, payload parsing, Nearby assist, or file-promise handling.
- Do not shrink the physical Sensor panel.

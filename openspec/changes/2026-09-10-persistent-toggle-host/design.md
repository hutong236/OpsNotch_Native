# Design

## Architecture
Replace the two-item ordinary hidden-section implementation with one AppKit status item:

```text
hiddenHostItem = [ variable spacer ........ ][ ‹ / │ ]
                                             ↑ fixed 16pt, Ops Notch side
```

`hiddenHostItem.length` is the only width that changes for the ordinary hidden section. Its `NSStatusBarButton` hosts a borderless child `NSButton`, constrained to the visible edge: trailing on LTR layouts and leading on RTL layouts.

## State mapping
- `collapsed`: host width = calculated hiding width + toggle width; child title = `‹`.
- `hiddenExpanded`: host width = 17pt resting width; child title = `│`.
- `allExpanded`: host width = 17pt resting width; child title = `│`.

The always-hidden separator remains a separate status item and keeps its existing behavior.

## Position persistence
The combined host reuses `lab.hutong.opsnotch.menubar.hidden-separator`, previously owned by the visible toggle/separator. This keeps the established boundary position across upgrades without relying on relative ordering between a newly introduced spacer status item and the toggle.

## Boundaries
AX hidden-section classification and notch probing use the host window's hidden-side edge. Position validation only needs to verify `Always Hidden → hiddenHostItem → Ops Notch` in LTR (mirrored for RTL).

## Auto-hide
Auto-hide may transition the real menu-bar section back to `collapsed`, but this only grows the host's spacer portion. The child `‹` remains pinned to the visible edge and must remain available for the next reveal action.

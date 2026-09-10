# Design

## Architecture
Use three independent status-item roles for the normal hidden section and the Ops Notch panel entry:

```text
LTR menu bar
... hidden apps ... [hiddenSpacerItem] [hiddenToggleItem ‹/│] [controlItem Ops Notch]
                         variable              fixed 16pt            fixed
```

`hiddenSpacerItem` is the only item whose width changes during normal-section collapse/expand. `hiddenToggleItem` never participates in hiding geometry and always stays at a fixed width. `controlItem` remains completely independent and opens only the proxy hidden-items panel.

## Position persistence
Status items use these autosave roles:

- Ops Notch: `lab.hutong.opsnotch.menubar.control`
- Toggle: reuse `lab.hutong.opsnotch.menubar.hidden-separator` so the existing visible control position survives upgrade
- Spacer: use a new v3 autosave name so stale position data from the failed two-item experiment cannot be reused
- Always-hidden divider: keep its existing autosave name

Before each status item is created, initialize `NSStatusItem Preferred Position <autosaveName>` only when missing. Defaults are chained from the item to its visible side so the initial LTR order is `Always Hidden → Spacer → Toggle → Ops Notch` (mirrored by AppKit for RTL).

When a status item must be hidden because menu-bar management or the always-hidden section is disabled, cache and restore its preferred-position default around `isVisible = false`. AppKit otherwise deletes that stored position.

## State mapping
- `collapsed`: spacer width = calculated hiding width; toggle width = 16pt; toggle title = `‹`.
- `hiddenExpanded`: spacer width = 1pt; toggle width = 16pt; toggle title = `│`; always-hidden divider may expand.
- `allExpanded`: spacer width = 1pt; toggle width = 16pt; toggle title = `│`; always-hidden divider returns to normal width.

## Boundaries
AX scanning and notch probing use the hidden-side edge of `hiddenSpacerItem`. Position validation checks the logical order of Ops Notch, fixed toggle, spacer, and optional always-hidden divider.

## Interaction boundaries
- Ops Notch left click: hidden-items proxy panel only.
- Toggle left click: real system menu-bar normal hidden section only.
- Toggle right click: management context menu.
- Auto-hide changes spacer width only and never changes toggle visibility/width.

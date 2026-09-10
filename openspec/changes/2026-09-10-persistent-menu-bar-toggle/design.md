# Design

## Status-item layout

LTR logical order:

```text
Always Hidden ¦  →  hiddenSpacerItem  →  hiddenToggleItem  →  Ops Notch
                                   (‹ / │, fixed width)
```

`hiddenSpacerItem` is created after `hiddenToggleItem`, so AppKit's default right-side insertion behavior places the spacer to the toggle's left. The visible toggle reuses the legacy `lab.hutong.opsnotch.menubar.hidden-separator` autosave name so upgrades inherit the user's previous visible separator position. The new spacer uses `lab.hutong.opsnotch.menubar.hidden-spacer`.

## State mapping

- `collapsed`: hidden spacer grows to `collapsedLength()`, toggle stays fixed and displays `‹`.
- `hiddenExpanded`: hidden spacer returns to 1 pt, toggle stays fixed and displays `│`; always-hidden separator may expand as before.
- `allExpanded`: hidden spacer stays at 1 pt and toggle displays `│`.

Only spacer lengths participate in animation. The toggle length is reasserted as fixed during state application/animation.

## Input routing

- Ops Notch left click: hidden-items proxy panel only.
- Ops Notch right click: management menu.
- `hiddenToggleItem` left click: real menu-bar hidden-area toggle.
- `hiddenToggleItem` right click: management menu.
- The invisible spacer has no action and is disabled.

## Geometry

Order validation uses the edge nearest the next always-visible item so a wide spacer does not invalidate ordering merely because its outer edge moved. AX hidden-section classification uses the spacer's outer/hidden-side edge: `minX` on LTR and `maxX` on RTL.

## Risks

macOS owns status-item ordering. The migration preserves the old visible separator autosave slot and relies on AppKit insertion order for the new spacer. Real-Mac validation should verify upgraded and fresh-install layouts, including notch displays and multi-display setups.

# Design

## Boundaries
`MenuBarManager` owns both AppKit status-item entry points, but they must not share user-visible state semantics.

### Ops Notch control
- Keeps a stable Ops Notch glyph and tooltip.
- Left click remains a hidden-items panel action when that optional panel is enabled.
- Real-menu-bar visibility changes must not alter its glyph, tooltip, or click meaning.

### `‹ / │` control
- Remains the fixed child button inside the variable-width hidden host so collapse cannot push the reveal control into the hidden region.
- Its title alone reflects the real menu-bar state: `‹` when collapsed and `│` when expanded.
- Left click directly transitions between `.collapsed` and `.hiddenExpanded` through `setState`.
- It must not call the notch-aware proxy-panel fallback path.

## Why keep the single host
The prior two-`NSStatusItem` implementation was unstable on real Macs because autosaved ordering and dynamic menu-bar layout could place the toggle on the hidden side of the spacer. The single host fixes that geometry problem. Issue #75 is therefore implemented by separating behavior/state semantics, not by reintroducing two independently restored status items.

## Non-goals
- No Quick Shelf changes.
- No persistence format changes.
- No removal of the existing menu-bar management master setting.
- No change to right-click management menus.

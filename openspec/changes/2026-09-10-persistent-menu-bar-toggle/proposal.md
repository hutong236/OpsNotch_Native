# Proposal: Persistent menu-bar hidden toggle

## Problem
The current normal-hidden separator is both the variable-width spacer that pushes third-party menu extras out of view and the user's clickable reveal/collapse control. When that status item becomes very wide in the collapsed state, its clickable affordance can leave the visible menu-bar area, leaving no obvious way to reveal hidden items.

## Change
Split the responsibility into two native `NSStatusItem`s:

- `hiddenSpacerItem`: invisible/non-interactive and variable width; only responsible for hiding/revealing the real system menu-bar region.
- `hiddenToggleItem`: fixed width and always visible while menu-bar management is enabled; shows `‹` when collapsed and `│` when expanded; left click toggles the real hidden area and right click opens management.

The Ops Notch control remains dedicated to opening the hidden-items proxy panel.

## Scope
- Menu-bar manager only.
- Preserve existing hidden-items panel behavior and AX scan architecture.
- Preserve existing autosave position for upgrading users by assigning the old hidden-separator autosave key to the new visible toggle.
- No Quick Shelf / temporary stash changes.

Tracks #68.

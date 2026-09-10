# Proposal: Decouple Ops Notch from the real menu-bar toggle

## Problem
Issue #75 requires two visually adjacent controls to represent two independent capabilities. The current implementation has already separated their click targets, but two residual couplings remain:

- the Ops Notch icon and tooltip still change with the real menu-bar visibility state;
- `‹ / │` can enter notch-overflow protection and open the hidden-items proxy panel instead of only expanding/collapsing the real system menu bar.

That makes the controls look and behave less independent than the product model requires.

## Change
- Keep Ops Notch presentation independent from `MenuBarVisibilityState`.
- Make `‹ / │` use a direct real-menu-bar state transition and never route through the hidden-items proxy panel.
- Preserve the current persistent single-host geometry that keeps `‹ / │` visible in collapsed/expanded/auto-hide states.
- Keep right-click management behavior and existing settings unchanged.
- Do not modify Quick Shelf / stash behavior.

## User model
- **Ops Notch** = hidden-items proxy panel entry.
- **`‹ / │`** = real system menu-bar expand/collapse entry.

## Issue
Closes #75.

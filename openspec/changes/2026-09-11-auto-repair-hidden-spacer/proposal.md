# Fix v2.7.8 menu-bar order false positive

## Problem

v2.7.8 separates the persistent `‹ / │` toggle from the internal variable-width spacer. This keeps the toggle visible, but the order validator still requires the invisible spacer to remain on the hidden side of the toggle.

When a user Command-drags the visible toggle, macOS updates the toggle's preferred position but the invisible spacer does not move with it. The visible order can therefore be correct while `positionValidation()` reports an invalid order and blocks Collapse.

Because the spacer is internal and invisible, asking the user to drag visible controls cannot repair this state.

## Change

- Treat the hidden spacer as an internal implementation detail, not a user-correctable validation target.
- Before collapsing/expanding the managed section, automatically align the spacer's preferred position with the current persistent toggle position.
- Recreate the spacer only when its preferred position is stale, so AppKit reloads the corrected autosaved position.
- Keep user-facing validation limited to visible controls (`¦`, `‹/│`, Ops Notch).
- Do not change Quick Shelf / staging behavior.

## Acceptance

1. With visually correct order `¦ → hidden icons → ‹/│ → Ops Notch`, Collapse must not show an order-invalid alert merely because the invisible spacer is stale.
2. After Command-dragging `‹/│`, the next collapse automatically reattaches the internal spacer to the hidden side of the toggle.
3. `‹/│` remains a fixed-width independent status item and remains visible while collapsed.
4. A genuinely wrong visible order still produces the existing guidance alert.

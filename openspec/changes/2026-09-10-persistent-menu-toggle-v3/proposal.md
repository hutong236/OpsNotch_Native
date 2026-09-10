# Proposal

## Problem
The current ordinary hidden-section implementation combines a variable-width hiding spacer and the visible `‹ / │` control inside one `NSStatusItem`. When that status item grows to displace hidden menu-bar items, macOS still lays out the whole status item as one menu-bar unit. The child button can therefore be displaced or clipped together with its host, so the reveal control is not guaranteed to remain visible.

An earlier split implementation used separate toggle and spacer status items, but relied on creation order plus autosave restoration. That did not provide a stable relative position after upgrades/relaunches.

## Change
Adopt the mature menu-bar-manager pattern used by projects such as Ice, Dozer, and HiddenBarIcons:

- keep the user interaction control in its own fixed-width status item;
- keep hiding geometry in a separate variable-width spacer status item;
- establish preferred positions before creating the status items;
- preserve preferred-position defaults when temporarily removing status items;
- use the spacer—not the toggle—as the AX/notch hidden-section boundary.

## Scope
Only menu-bar icon management changes. Quick Shelf / staging behavior is unchanged.

## Success criteria
- `‹ / │` remains visible through launch-collapsed, manual collapse, auto-hide, screen changes, and repeated toggles.
- Ops Notch remains a panel-only entry; `‹ / │` remains a real-menu-bar-only entry.
- Existing hidden-section placement is migrated without requiring users to rediscover the control.

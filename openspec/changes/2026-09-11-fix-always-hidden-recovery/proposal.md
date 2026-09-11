# Fix always-hidden recovery and reveal race

## Problem

The explicit “Show All” action currently goes through the notch-overflow probe. It briefly expands the real menu bar, then may collapse it again and open the Hidden Items Panel. This makes the always-hidden section flash and disappear.

An item such as WeChat that was Command-dragged into the always-hidden section can then become effectively unreachable: the proxy panel can activate the item, but it cannot rearrange third-party status-item positions, while the real always-hidden section does not stay visible long enough for the user to Command-drag the item back.

A second race exists because a delayed notch probe may finish after the user has already selected another explicit visibility state and overwrite that newer choice.

## Change

- Make the explicit “Show All” action a real-system-menu-bar recovery path instead of a notch-aware proxy action.
- Close the Hidden Items Panel before showing the always-hidden section so both surfaces cannot appear together.
- Do not arm auto-hide for this explicit recovery action; the section stays visible for manual Command-drag rearrangement.
- Invalidate any pending notch-overflow probe whenever a direct visibility state request is made, so stale delayed results cannot overwrite the latest user action.
- Keep normal hidden-section expansion notch-aware; only the explicit all/always-hidden recovery path bypasses proxy redirection.
- Do not attempt to programmatically move third-party menu-bar items.

## Acceptance

1. Choosing “Show All” while the always-hidden section is enabled must keep the real always-hidden section visible instead of flashing and collapsing into the Hidden Items Panel.
2. If the Hidden Items Panel is already open, “Show All” closes it before the real section is revealed.
3. A WeChat/menu-extra item in the always-hidden section remains visible long enough to be Command-dragged back across the separator.
4. The explicit recovery reveal does not auto-hide by its normal timer immediately after opening.
5. A pending notch probe cannot later reopen the proxy panel or collapse a newer explicit state.
6. Normal hidden-section reveal retains the existing notch-overflow protection.

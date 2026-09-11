# Design: always-hidden recovery reveal

## State ownership

`MenuBarManager` remains the single owner of menu-bar visibility state and spacer geometry. The Hidden Items Panel remains a proxy interaction surface only; it does not own or mutate third-party status-item positions.

## Explicit recovery path

`showAll()` is treated as a user recovery/arrangement command rather than an overflow-protected convenience reveal. It therefore:

1. clears the “panel opened for notch overflow” marker;
2. closes the proxy popover if it is visible;
3. requests `.allExpanded` directly;
4. disables auto-hide scheduling for that request.

This guarantees that the actual always-hidden section remains on screen so macOS's native Command-drag behavior can be used to move an item back.

## Probe invalidation

Notch overflow detection is asynchronous: `showNotchAware` records a generation and evaluates the result after a short delay. Any direct call to `setState` now increments that generation before applying its state. Delayed probes therefore become stale and return without mutating UI.

This keeps last-user-action-wins semantics for collapse, persistent-toggle changes, startup state application, and explicit all-expanded recovery.

## Scope

The normal hidden section continues to use `showNotchAware(.hiddenExpanded)` and can still redirect overflow to the Hidden Items Panel on notched displays. No Accessibility or private API is added for moving third-party status items.

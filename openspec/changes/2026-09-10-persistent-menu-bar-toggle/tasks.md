# Tasks

- [x] Split the normal hidden-area spacer from the visible toggle status item.
- [x] Keep `‹ / │` at a fixed width and visible while menu-bar management is enabled.
- [x] Reuse the legacy hidden-separator autosave key for the visible toggle.
- [x] Route left click on `‹ / │` to real hidden-area expand/collapse and right click to management.
- [x] Keep Ops Notch left click dedicated to the hidden-items proxy panel.
- [x] Move animation to the hidden spacer while preserving the toggle width.
- [x] Update position validation, AX boundaries, and notch probing to use the spacer geometry.
- [x] Run `swift test`, `swift build`, and `python3 scripts/static_checks.py` on macOS.
- [ ] Manually verify upgrade ordering, fresh-install ordering, notch displays, and multiple displays on a real Mac.

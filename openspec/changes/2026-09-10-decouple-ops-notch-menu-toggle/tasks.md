# Tasks

- [x] Audit current `MenuBarManager` behavior against issue #75.
- [ ] Make Ops Notch glyph/tooltip independent from real menu-bar visibility state.
- [ ] Route `‹ / │` left click directly to real menu-bar expand/collapse state transitions.
- [ ] Ensure the `‹ / │` path cannot open or alter the hidden-items proxy panel.
- [ ] Preserve the persistent single-host geometry for collapsed/expanded/auto-hide states.
- [ ] Run `swift test`, `swift build`, and `python3 scripts/static_checks.py` through CI.
- [ ] Manually verify collapsed/expanded, auto-hide, notch, and multi-display behavior on a real Mac.

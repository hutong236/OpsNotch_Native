# Tasks

- [x] Change explicit Show All to bypass notch-aware proxy redirection.
- [x] Close the Hidden Items Panel before revealing the real always-hidden section.
- [x] Disable auto-hide scheduling for the explicit recovery reveal.
- [x] Invalidate pending notch probes on direct visibility-state requests.
- [ ] Verify `swift build`, `swift test`, and `python3 scripts/static_checks.py` in CI.
- [ ] Manual macOS check: Command-drag WeChat into always-hidden, reveal all, then Command-drag it back.
- [ ] Manual notched-display check: ordinary hidden-section reveal still redirects overflow to the panel when necessary.

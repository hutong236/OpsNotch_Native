# Tasks

- [x] Add a pure `HoverIntentPolicy` to distinguish lower-edge entry from horizontal traversal.
- [x] Add unit tests for accepted entry, rejected side entry, and movement cancellation.
- [x] Reduce ordinary-hover tracking geometry to 100×8pt on notched and non-notched displays.
- [x] Increase ordinary-hover dwell to 0.4s.
- [x] Cancel pending hover intent when pointer travel exceeds 6pt.
- [x] Preserve full Sensor drag/drop bounds and existing Nearby drag-assist behavior.
- [ ] Verify `swift test`.
- [ ] Verify `swift build`.
- [ ] Verify `python3 scripts/static_checks.py`.
- [ ] Run manual macOS smoke checks for horizontal menu-bar traversal and deliberate upward hover.

Tracks #79.

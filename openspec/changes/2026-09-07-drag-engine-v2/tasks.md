# Tasks: Drag Engine V2

> Scope closeout: this change is limited to solving the original drag-in discoverability problem on notch/non-notch Macs. Deferred product ideas and architecture-only refactors are not blockers for this requirement.

## Core requirement — completed

- [x] Detect supported external drag sessions with global mouse drag/up events plus `NSPasteboard(name: .drag)` changeCount/types.
- [x] Do not add continuous drag polling or new Accessibility/Input Monitoring requirements.
- [x] Show one non-activating Nearby Drop Zone near the pointer so the user no longer needs to find the notch Sensor precisely.
- [x] Clamp/flip the Drop Zone within the current display and migrate the single target when the drag crosses displays.
- [x] Keep the existing top Sensor as the stable fallback; when Shelf/Sensor is visible the Nearby target yields to it.
- [x] Cancel/unused drag sessions return to idle and remove the temporary UI.
- [x] Use one `DropPayloadResolver` for Nearby Overlay, top Sensor and expanded Shelf.
- [x] Support Finder file URLs plus `NSFilePromiseReceiver` for Safari/Photos-style promised files.
- [x] Promise resolution uses session-scoped staging, async `OperationQueue`, partial-success ingestion and cleanup.
- [x] Clean stale File Promise staging on the next app launch after abnormal termination.
- [x] Preserve real file semantics when ingesting files; promised files are copied into Shelf-managed storage before staging cleanup.
- [x] Provide success/receiving feedback without logging dragged content.
- [x] Persist optional Drag Assist mode with backward-compatible default: Nearby or Sensor-only.
- [x] Nearby Drag Assist honors Reduce Motion and exposes VoiceOver label/help.

## Included hardening already merged

These changes were implemented while delivering Drag Engine V2 and are retained, but no further expansion is required for this issue:

- [x] Native drag-out lifecycle uses AppKit final drag operation instead of assuming success.
- [x] Ordinary temporary items can be consumed after successful drag-out; pinned/Working Set items remain protected.
- [x] One-step drag-out Recall/Undo including crash-safe restoration of managed copies.

## Automated validation — completed

- [x] `swift test`
- [x] Debug `swift build`
- [x] `python3 scripts/static_checks.py`
- [x] `drag_assist_mode` backward-compatibility and Codable round-trip tests.
- [x] File Promise stale staging cleanup is wired before any new drag session starts.

## Release/manual acceptance for this requirement

These are release verification checks, not new development scope:

- [ ] Notch MacBook: Finder single file, multiple files and folder can see/use Nearby Drop Zone without aiming at the notch point.
- [ ] Non-notch display: Drop Zone stays inside usable screen area and does not obstruct menu bar/Dock.
- [ ] External dual displays: one Drop Zone follows the active drag from display A to B.
- [ ] Cancel/no-drop: temporary UI disappears and Shelf gains no item.
- [ ] Nearby Overlay, top Sensor and expanded Shelf each ingest one dropped payload only once.
- [ ] Safari/Chrome URL/text/web image and Photos single/multiple image File Promise smoke test.
- [ ] Spaces/full-screen smoke test confirms the non-activating target does not steal focus.
- [ ] Default upgrade/first launch does not prompt for Accessibility/Input Monitoring because of Drag Assist.
- [ ] Sensor-only setting suppresses Nearby Overlay while top Sensor remains usable.

## Explicitly out of scope

The following are **not part of this requirement and will not be developed under Issue #47**:

- Ignored-app/source-app exclusion lists.
- Multi-file Stack/grouping UI or persisted Stack model.
- Additional payload-priority refactoring solely for architecture cleanliness.
- A separate persisted `locked` model beyond existing pinned/Working Set behavior.
- Further Finder modifier-key behavior changes beyond preserving safe native file semantics.
- Extra Drag Engine features unrelated to fixing drag-in discoverability/reliability.

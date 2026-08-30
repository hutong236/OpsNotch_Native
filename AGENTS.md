# AGENTS.md — OpsNotch Native

## What this is

Ops Notch V2: a macOS notch/shelf utility (drag files, folders, URLs, or selected text to a sensor at the top of each display; clipboard catch; pinned/recent). It is a native rewrite of an earlier Tauri/React version — **Swift + AppKit + SwiftUI, Swift Package Manager only**. No Node.js, npm, Vite, Xcode project, or localhost server (the app must never listen on port 1420, the old Tauri dev port).

Minimum platform: **macOS 13**, Swift 5.9. Project docs (README, ARCHITECTURE, VERIFY_ON_MAC) are written in Chinese.

## Layout

- `Sources/OpsNotchCore/` — pure logic and models: `Models.swift` (ShelfItem/ShelfSettings), `ShelfLogic.swift`, `ShelfStoreService.swift` (JSON persistence + legacy migration), `SafeActionValidator.swift`, `HotkeyValidation.swift`, `ItemPreviewKind.swift`. Must stay UI/AppKit-free so it is unit-testable.
- `Sources/OpsNotchApp/` — executable target, depends on Core: AppKit system layer (`SensorManager`, `ShelfWindowController`, `ClipboardManager`, `StatusBarController`, `QuickLookService`, `ItemActionService`, `LoginItemService`, `HotkeyService`, `FloatingPreviewController`) and SwiftUI content (`ShelfView`, `SettingsWindowController`, `HotkeyRecorder`), plus `Localization.swift`, `AppModel.swift`, `AppVersionService.swift`.
- `Tests/OpsNotchCoreTests/` — XCTest for Core only.
- `script/build_and_run.sh` — V2 dev entry (note: this is `script/`, singular). `scripts/` (plural) holds `build_app.sh`, `run_dev.sh`, `static_checks.py`.
- Data files live outside the repo at `~/Library/Application Support/lab.hutong.opsnotch/` (`shelf.json` + `shelf-files/`).
- `openspec/` — change proposals (`openspec/changes/<name>/` with proposal/design/specs/tasks) drive feature work; use the `openspec-propose` / `openspec-apply-change` skills for proposing and implementing changes, and archive completed ones to `openspec/changes/archive/`.

## Commands

```bash
swift build                          # debug build
swift test                           # Core unit tests
python3 scripts/static_checks.py     # CI gate, see gotchas below
./script/build_and_run.sh            # build, bundle as .app in dist/, codesign ad-hoc, launch
./script/build_and_run.sh --debug    # variants: --logs, --telemetry, --verify
./scripts/build_app.sh               # release .app in build/ (ad-hoc codesign)
```

CI (`.github/workflows/macos-ci.yml`) runs: `swift test`, `swift build`, `scripts/static_checks.py`, `scripts/build_app.sh`. There is no formatter/linter configured.

## Architecture rules

- Dependency direction is one-way: `OpsNotchApp` → `OpsNotchCore`. Never import AppKit/SwiftUI into Core.
- **AppKit owns system interaction; SwiftUI owns content only.** Sensors, windows, drag & drop, pasteboard, status item stay AppKit. Do not reimplement notch/sensor/drag behavior with SwiftUI gestures.
- Sensor is one transparent `NSPanel` per `NSScreen` using `NSTrackingArea` + `NSDraggingDestination`. Rebuild on `NSApplication.didChangeScreenParametersNotification` — do not reintroduce polling (V1.x polled every 1.5s).
- Clipboard Catch dedupes via `NSPasteboard.general.changeCount` baseline; when the app itself copies an item, ClipboardManager must update the baseline immediately or the same content re-enters Recent.
- **Safe actions**: item actions may only open absolute local paths or http/https URLs, always via `SafeActionValidator.validate`. No shell/SSH/kubectl/arbitrary command execution, ever.
- Storage stays compatible with legacy V0.x/V1.x `shelf.json` (root-array format, `ip`/`command` types migrate to Text). Tests cover these migrations — don't break them.
- Localization is runtime zh/en switching through `L10n.text(key, language)` dictionaries in `Localization.swift` — not `.strings`/`.xcassets`. Add new UI strings to both language dicts.
- The app runs as accessory (`setActivationPolicy(.accessory)`): no Dock icon, `NSStatusItem` menu instead. A user-configurable global summon hotkey is allowed **only** as an opt-in setting (default off/nil, recorded in the settings UI, persisted in `shelf.json`): implement via Carbon `RegisterEventHotKey` behind the `HotkeyService` protocol (zero-permission, event-consuming so keys never leak to the frontmost app), never via global event monitors that require Input Monitoring permission, and never via third-party hotkey plugins.

## Gotchas

- `scripts/static_checks.py` scans every `.swift`/`.json`/`.plist` file and fails CI if the strings `tauri`, `react`, `vite`, or `global-shortcut` appear (case-insensitive), and requires exact API call sites: `registerForDraggedTypes([.fileURL, .URL, .string])`, `changeCount`, `NSScreen.screens`, `didChangeScreenParametersNotification`, `NSStatusBar.system.statusItem`, `QLPreviewPanel`, `SMAppService.mainApp`, `setActivationPolicy(.accessory)`, `SafeActionValidator.validate`. Keep these intact when refactoring, or update the checker deliberately in the same change.
- `swift run` launches a bare process, not a full app bundle — login item (`SMAppService`) and notch/sensor behavior only behave correctly when tested via the bundled `.app` from `./script/build_and_run.sh` or `./scripts/build_app.sh`.
- Real multi-display, drag & drop, and clipboard behavior cannot be verified in CI or unit tests. Manual acceptance follows the checklist in `VERIFY_ON_MAC.md`.
- Read `ARCHITECTURE.md` before touching SensorManager/ClipboardManager/ShelfWindowController, and `MIGRATION_FROM_TAURI.md` before touching `ShelfStoreService` persistence formats.

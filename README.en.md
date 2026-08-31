# Ops Notch

<p align="center">
  <strong>A native macOS shelf for temporarily holding files, text, and links at the edge of the notch.</strong>
</p>

<p align="center">
  <a href="https://github.com/hutong236/OpsNotch_Native/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/hutong236/OpsNotch_Native/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/hutong236/OpsNotch_Native/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/hutong236/OpsNotch_Native"></a>
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-black">
  <img alt="Swift 5.9+" src="https://img.shields.io/badge/Swift-5.9%2B-F05138">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-blue"></a>
</p>

<p align="center">
  <a href="README.md">简体中文</a> · English
</p>

Ops Notch is a native macOS utility for temporarily holding files, folders, URLs, applications, and selected text. Drag content to the transparent sensor at the top of any display, or copy text and touch the sensor to capture it in Recent. The app stays out of the Dock and is managed from the menu bar.

## Install

1. Download the macOS archive from the [latest release](https://github.com/hutong236/OpsNotch_Native/releases/latest).
2. Unzip it and move Ops Notch.app to Applications.
3. Release artifacts are currently ad-hoc signed and not notarized. On first launch, Control-click the app and choose Open.

Automated release artifacts currently target Apple Silicon (arm64). Intel Mac users can build from source.

## Highlights

- Native file, folder, application, URL, and selected-text drag and drop.
- Clipboard Catch with NSPasteboard change-count deduplication.
- Pinned and Recent sections, search, type filters, multi-selection, and retention cleanup.
- Keyboard retrieval flow with arrows, Enter, Space, Escape, and Command+1 through Command+5.
- One event-driven sensor per display, including hot-plug and display-layout changes.
- Quick Look, Reveal in Finder, launch at login, runtime Chinese/English switching, and an optional global summon hotkey.
- Safe actions limited to absolute local paths and HTTP/HTTPS URLs. No shell or arbitrary command execution.
- Native Swift, AppKit, SwiftUI, and Swift Package Manager only; no local web server.

## Build from source

Requirements:

- macOS 13 or later
- Swift 5.9 or later
- Xcode 15 or later recommended

Run the quality gates:

    swift test
    swift build
    python3 scripts/static_checks.py

Build and launch a complete app bundle:

    ./script/build_and_run.sh

Build a release app:

    ./scripts/build_app.sh
    open "build/Ops Notch.app"

Use an app bundle for manual testing of launch-at-login, notch sensors, multi-display behavior, drag and drop, and clipboard integration.

## Architecture

| Layer | Responsibility |
|---|---|
| OpsNotchCore | Models, filtering, persistence, migration, and safe-action validation |
| AppKit | Sensors, windows, displays, drag and drop, pasteboard, status item, and Quick Look |
| SwiftUI | Shelf content, search, filters, editing, and settings |
| Swift Package Manager | Dependency-free build and test workflow |

See [ARCHITECTURE.md](ARCHITECTURE.md) for the complete design.

## Local data

Ops Notch stores data locally under:

    ~/Library/Application Support/lab.hutong.opsnotch/

See [MIGRATION_FROM_TAURI.md](MIGRATION_FROM_TAURI.md) before changing or migrating the storage format.

## Contributing and support

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Use GitHub Issues for reproducible defects and scoped feature proposals. Security-sensitive reports must follow [SECURITY.md](SECURITY.md).

## License

Ops Notch is available under the [MIT License](LICENSE).
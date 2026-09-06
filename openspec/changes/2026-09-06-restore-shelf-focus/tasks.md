# Tasks

- [x] Add an AppKit focus-return coordinator for Quick Shelf key-window sessions.
- [x] Capture the original frontmost application without introducing new permissions.
- [x] Restore focus only after the Shelf is hidden and only when the original application is still frontmost.
- [x] Invalidate restoration when the user intentionally switches to another application.
- [x] Wire the coordinator into the application lifecycle without changing Core or SwiftUI content ownership.
- [ ] Run `swift build`, `swift test`, and static checks in CI/macOS environment.
- [ ] Manually verify direct `⌘V` in Cursor/VS Code/browser text fields after Quick Shelf closes.

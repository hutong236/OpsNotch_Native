# Design

## Approach
Keep the existing `ShelfPanel` implementation unchanged: it remains an `NSPanel` with `.nonactivatingPanel` and may become key only for the expanded keyboard/search flow.

Add `FocusReturnCoordinator` in `OpsNotchApp`. The coordinator observes `NSWindow.didBecomeKeyNotification` and `NSWindow.didResignKeyNotification` only for `ShelfPanel` instances.

When the Shelf becomes key, the coordinator records `NSWorkspace.shared.frontmostApplication` if it is not the Ops Notch process. Because the Shelf is non-activating, that application represents the user's original application.

When the Shelf resigns key, handling is deferred for one main-actor turn so `ShelfWindowController` can finish its existing hide/order-out path. Then:
- If the panel is still visible, no focus is restored. A switch to another external frontmost application invalidates the old session.
- If the panel is hidden and the recorded application is still frontmost, call `NSRunningApplication.activate(options: [])` to cooperatively restore its normal key-window / first-responder flow.
- If another application (or an Ops Notch settings/file panel) became frontmost, do nothing.
- If the recorded application terminated, discard the session.

## Why not Accessibility
The expected case only needs to return control to the same application. macOS applications normally preserve their own first responder while inactive/key-window state changes. Using AX focused-element APIs would add permission friction and a much larger failure surface, so it is intentionally excluded.

## Boundaries
- AppKit owns all focus/window lifecycle behavior.
- `OpsNotchCore` remains unchanged and AppKit-free.
- SwiftUI views and clipboard persistence do not participate in focus restoration.
- No deprecated force-activation option is used.

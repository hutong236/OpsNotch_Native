# Restore original app focus after Quick Shelf interaction

## Why
Quick Shelf is already a non-activating panel, but its expanded keyboard flow deliberately becomes the key window so users can type, navigate, and press Enter. When the panel later closes, the previously focused application does not always regain its input focus, forcing the user to click the original text field before pasting.

## What changes
- Add one AppKit-owned focus-return coordinator for Quick Shelf key-window sessions.
- Capture the frontmost external application when Quick Shelf becomes key.
- After Quick Shelf leaves the key-window flow and is actually hidden, request activation of the captured application so its existing key window / first responder can resume.
- Cancel the old focus-return session if the user switches to a different application while Quick Shelf is open.
- Keep drop/success-only panel states passive and preserve the existing `.nonactivatingPanel` window architecture.
- Add no Accessibility or Input Monitoring permission requirement.

## Out of scope
- Persisting or manipulating another application's AX focused element.
- Synthesizing paste keyboard events.
- Changing clipboard payload semantics or Quick Shelf ranking/search behavior.

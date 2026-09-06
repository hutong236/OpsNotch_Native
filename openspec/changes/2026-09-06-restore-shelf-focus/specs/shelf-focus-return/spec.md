# Quick Shelf focus return

## Requirements

### Capture original application
When the expanded Quick Shelf becomes the key window, the application MUST remember the current frontmost external application and MUST NOT treat the Ops Notch process itself as the return target.

### Restore after hide
When the Quick Shelf finishes its key-window interaction and is hidden, the application MUST request activation of the remembered application if that same application is still frontmost. This MUST allow the remembered application's existing input control to resume normal keyboard input without requiring a mouse click.

### Respect user app switching
If the user switches to a different external application while Quick Shelf is visible, the application MUST invalidate the old focus-return target and MUST NOT later steal focus back to it.

### Preserve modal flows
If Quick Shelf temporarily resigns key status because an in-app menu, sheet, settings window, or file panel takes focus while the Shelf remains visible, the application MUST NOT prematurely restore the external application.

### No new permissions
The focus-return behavior MUST NOT require Accessibility or Input Monitoring permission and MUST NOT synthesize keyboard input.

### Existing behavior
Clipboard payloads, Finder/App search, desktop commands, drag-and-drop, multi-display placement, and passive drop/success panel behavior MUST remain unchanged.

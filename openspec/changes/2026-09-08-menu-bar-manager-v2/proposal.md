# Proposal: Menu Bar Manager V2

## Why

Ops Notch already lives in the macOS menu bar and is intended to stay running. On Macs with a notch or many status items, useful icons are easily pushed out of reach. Adding native menu-bar region management keeps this problem inside the same lightweight utility instead of requiring a separate resident app.

## What changes

- Reuse the Ops Notch status item as the visible control.
- Add stable, Command-draggable separator items for a normal hidden section and an optional always-hidden section.
- Support three states: collapsed, normal hidden section expanded, and all sections expanded.
- Add automatic collapse, launch behavior, a dedicated Carbon hotkey, short transition animation, settings persistence, and multi-display width recalculation.
- Add an optional hidden-items panel. Basic hiding remains permission-free; the panel uses Accessibility only when the user explicitly enables/opens it.
- Preserve right-click access to the existing Ops Notch menu and explicit Quit action.

## Compatibility

The feature defaults to disabled for existing users. New ShelfSettings fields decode with defaults so legacy shelf.json files continue to load unchanged.

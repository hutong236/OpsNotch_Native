# Proposal: Hidden Panel Direct Interaction

## Problem

The hidden-items panel currently sits behind the Ops Notch right-click menu. After opening it, activating an item first expands the menu bar, closes the panel, waits, and then triggers the original menu-bar item. This creates a slow, indirect interaction and makes the right-click menu a mandatory high-frequency path.

## Goal

Turn the hidden-items panel into a first-class launcher for hidden menu-bar items without changing Quick Shelf behavior.

## Scope

- When the hidden-items panel feature is enabled, a normal left click on the Ops Notch menu-bar control opens the panel directly.
- Keep right click for the Ops Notch management menu and Option-click for showing all sections.
- Support distinct primary and secondary actions for panel items: left click prefers AXPress; right click prefers AXShowMenu.
- Trigger the original AX element directly while it remains hidden. Do not automatically expand the menu bar before activation.
- Cache the Ops Notch context menu and rebuild it on settings/state changes instead of constructing it on the right-click display path.
- Keep the existing optional Accessibility permission model.

## Non-goals

- No changes to Quick Shelf, clipboard, drag/drop, or temporary storage behavior.
- No polling for menu-bar changes.
- No private API or mutation of third-party status items.

## Tracking

GitHub issue: #61

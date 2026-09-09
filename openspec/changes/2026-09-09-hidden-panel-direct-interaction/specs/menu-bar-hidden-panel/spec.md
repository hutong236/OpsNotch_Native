# Hidden Items Panel Interaction

## Requirements

### Direct panel entry

When menu-bar management and the Hidden Items Panel are enabled, a normal left click on the Ops Notch menu-bar control MUST open the hidden-items panel directly. The user MUST NOT need to open the Ops Notch context menu first.

Right click MUST continue to open the Ops Notch context menu. Option + left click MUST continue to show all managed menu-bar sections.

### Direct hidden-item interaction

A normal click on a hidden item in the panel MUST invoke the original item's primary Accessibility action without first expanding the managed menu-bar regions.

A right click on a hidden item in the panel MUST invoke the original item's menu/secondary Accessibility action without first expanding the managed menu-bar regions.

When the preferred Accessibility action is unavailable, the implementation MAY fall back to the other supported action. If neither succeeds, it MUST surface the existing activation-failure feedback and MUST NOT automatically restore the item to the visible menu bar.

### Responsive Ops Notch context menu

The Ops Notch context menu MUST be prebuilt outside the right-click presentation path. Settings or menu-bar state changes MUST refresh the cached menu so its labels and actions remain current.

### Permission boundary

Basic menu-bar hiding MUST remain permission-free. Accessibility permission MUST remain scoped to opening/using the optional Hidden Items Panel.

### Scope isolation

This change MUST NOT alter Quick Shelf behavior, clipboard capture, drag/drop behavior, or shelf persistence.

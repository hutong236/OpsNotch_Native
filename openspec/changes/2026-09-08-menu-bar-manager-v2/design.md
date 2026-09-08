# Design: Menu Bar Manager V2

## Architecture

`MenuBarManager` owns three native `NSStatusItem` objects: the Ops Notch control, the normal hidden separator, and the optional always-hidden separator. Their `autosaveName` values let macOS remember user Command-drag ordering across launches.

The controller never attempts to mutate third-party status items. Hiding is produced by expanding one of Ops Notch's own separator widths up to a bounded value derived from the widest attached display. Screen changes reapply the current state using `NSApplication.didChangeScreenParametersNotification`; no long-running polling is introduced.

### Three states

- `collapsed`: normal separator is wide; everything to its left is pushed out.
- `hiddenExpanded`: normal separator is narrow; when the always-hidden section is enabled, its separator is wide.
- `allExpanded`: both separators are narrow.

The expected left-to-right order is `always-hidden separator → normal separator → Ops Notch control`. Invalid ordering degrades to fully expanded rather than risking loss of the control item.

## Interaction

- Left click: toggle normal hidden section.
- Option + left click: show all sections.
- Control + left click: open optional hidden-items panel.
- Right click: existing Ops Notch context menu plus menu-bar controls.
- Dedicated Carbon hotkey uses registration ID 2 and remains opt-in.

## Optional hidden-items panel

When enabled, the panel asks for Accessibility permission only when it is opened. It enumerates each running application's `kAXExtrasMenuBarAttribute`, identifies menu extras that fall inside the hidden regions after a temporary full expansion, and stores the original AX element reference. Activating an entry reveals all sections and invokes `AXShowMenu` or `AXPress` on the original item.

The panel is deliberately optional so the core hide/show path has no new privacy permission.

## Performance

- Auto-hide uses one one-shot timer only while expanded.
- Transition animation uses one short-lived 60 Hz timer for about 160 ms and is user-disableable.
- Display changes are event-driven.
- Accessibility scanning runs only when the optional panel is opened or refreshed.

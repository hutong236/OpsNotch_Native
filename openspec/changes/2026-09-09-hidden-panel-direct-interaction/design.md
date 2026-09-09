# Design: Hidden Panel Direct Interaction

## Interaction routing

`MenuBarManager` keeps ownership of the native status items and maps events as follows when menu-bar management is enabled:

- Right click: show the Ops Notch context menu.
- Option + left click: show all managed menu-bar sections.
- Left click with Hidden Items Panel enabled: open the panel immediately.
- Left click with Hidden Items Panel disabled: preserve the existing hidden-area toggle.

The panel remains optional and therefore does not introduce Accessibility permission into the basic hide/show path.

## Direct hidden-item actions

The scanner retains the original `AXUIElement` for every discovered menu extra. Panel rows use a small AppKit mouse bridge so SwiftUI can distinguish normal and right clicks without presenting an intermediate context menu.

- Primary interaction prefers `AXPress` and falls back to `AXShowMenu`.
- Secondary interaction prefers `AXShowMenu` and falls back to `AXPress`.

The old activation path that expanded all separators, closed the panel, waited, invoked the item, and optionally collapsed again is removed. Unsupported AX elements fail with the existing toast instead of silently revealing the item first.

## Context-menu latency

`StatusBarController` owns a prebuilt `NSMenu`. `MenuBarManager` receives the cached menu through the existing provider and notifies `StatusBarController` when menu-bar state changes so the cache can be rebuilt outside the right-click presentation path. Settings changes already call `rebuildMenu()`.

## Risks

Some third-party menu extras expose only one Accessibility action. Fallback ordering preserves best-effort behavior. A menu opened through `AXShowMenu` may cause the transient popover to close; this is acceptable because the target menu is already active.

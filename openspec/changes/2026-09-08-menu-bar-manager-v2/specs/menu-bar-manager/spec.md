# Menu Bar Manager Specification

## Requirements

### Native separator regions

Ops Notch SHALL provide a permission-free menu-bar management mode using its own native status items. Users MUST be able to hold Command and drag the two region separators and other menu-bar icons to define the sections.

### Three visibility states

The manager SHALL support collapsed, hidden-expanded, and all-expanded states. When always-hidden mode is disabled, hidden-expanded and all-expanded MAY be visually equivalent except for stored state.

### Safe ordering

If the separators are not ordered correctly relative to the Ops Notch control, the manager SHALL fail open by showing all items and SHALL NOT intentionally hide the Ops Notch control.

### Automatic collapse

The user SHALL be able to select Never, 5, 10, 30, or 60 seconds. Auto-collapse SHALL defer while the pointer is inside a visible menu-bar band or the hidden-items panel is open.

### Global shortcut

The manager SHALL expose a separate opt-in Carbon hotkey from the Quick Shelf summon hotkey. Registration conflicts SHALL be shown without replacing the previously working shortcut.

### Persistent configuration

All menu-bar settings SHALL remain backward-compatible with existing shelf.json data. Existing installs SHALL start with menu-bar management disabled.

### Multi-display behavior

The collapsed separator length SHALL be derived from the widest connected display and recalculated on screen-parameter notifications. The requested width SHALL be bounded to 10,000 points.

### Optional hidden-items panel

The basic manager SHALL NOT require Accessibility permission. If the panel is enabled and opened, Ops Notch MAY request Accessibility permission and enumerate `AXExtrasMenuBar` items. A panel activation SHALL reveal the native menu bar before invoking the original AX item.

### Context menu and quit

Right-clicking the Ops Notch control SHALL keep Settings and explicit Quit reachable regardless of hide/show state.

# Menu-bar hidden toggle specification

## Requirement: fixed reveal control
The ordinary hidden-section reveal/collapse control SHALL be an independent fixed-width `NSStatusItem` whenever menu-bar management is enabled.

### Scenario: launch collapsed
- GIVEN menu-bar management is enabled and launch state is collapsed
- WHEN status items are restored
- THEN hidden menu-bar apps are displaced by the spacer
- AND `‹` remains visible and clickable.

### Scenario: repeated manual toggle
- GIVEN the normal hidden section is collapsed
- WHEN the user clicks `‹`
- THEN only the real system hidden section expands
- AND the toggle becomes `│` without changing its width or visibility.
- WHEN the user clicks `│`
- THEN the spacer collapses the section again
- AND the toggle becomes `‹` without being displaced.

### Scenario: automatic collapse
- GIVEN the section is expanded and auto-hide is enabled
- WHEN auto-hide fires
- THEN only the spacer expands to hide the section
- AND the fixed toggle remains visible and clickable.

## Requirement: stable status-item ordering
Status-item preferred-position defaults SHALL be established before status-item creation and SHALL survive temporary visibility changes.

### Scenario: upgrade from combined host
- GIVEN the existing `hidden-separator` autosave position exists
- WHEN v3 creates its status items
- THEN the fixed toggle reuses that position
- AND a new spacer autosave identity is placed on the hidden side of the toggle.

### Scenario: management disabled and re-enabled
- GIVEN status items have user-restored positions
- WHEN menu-bar management is disabled and later re-enabled
- THEN preferred positions are preserved
- AND the toggle/spacer ordering does not reset.

## Requirement: panel and system controls remain separate
- Ops Notch left click SHALL only open the hidden-items proxy panel when enabled.
- `‹ / │` left click SHALL only toggle the real system menu-bar hidden section.
- `‹ / │` right click SHALL open the management menu.

## Requirement: spacer owns hidden geometry
AX classification, notch probing, collapse animation, and hidden-section displacement SHALL use the independent spacer item and SHALL NOT use the fixed toggle item as hiding geometry.

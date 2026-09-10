# Menu-bar hidden toggle specification

## Requirement: reveal control remains available
The ordinary hidden-section reveal/collapse control SHALL remain visible and clickable whenever menu-bar management is enabled, including while the real hidden area is collapsed by startup state or auto-hide.

### Scenario: collapsed startup
- GIVEN menu-bar management starts collapsed
- WHEN Ops Notch finishes creating its status items
- THEN the real hidden menu-bar items are displaced
- AND `‹` remains visible next to Ops Notch.

### Scenario: manual toggle
- GIVEN the real hidden area is collapsed
- WHEN the user left-clicks `‹`
- THEN the real hidden area expands
- AND the control becomes `│`
- WHEN the user left-clicks `│`
- THEN the real hidden area collapses
- AND the control becomes `‹` without disappearing.

### Scenario: automatic collapse
- GIVEN the real hidden area is expanded and auto-hide is enabled
- WHEN the auto-hide condition is met
- THEN the real hidden area may collapse
- BUT the `‹` control SHALL remain visible and clickable.

## Requirement: panel and system-area actions stay separated
- Left-clicking the Ops Notch control SHALL open only the hidden-items proxy panel when that panel is enabled.
- Left-clicking `‹ / │` SHALL only reveal/collapse the real system menu-bar hidden area.
- Right-clicking the toggle SHALL open the Ops Notch management menu.

## Requirement: host owns hiding geometry
The ordinary hidden area SHALL use a single status-item host whose total width provides the hiding displacement and whose fixed child toggle is pinned to the edge nearest Ops Notch. AX section boundaries and notch overflow checks SHALL use the host's hidden-side edge.

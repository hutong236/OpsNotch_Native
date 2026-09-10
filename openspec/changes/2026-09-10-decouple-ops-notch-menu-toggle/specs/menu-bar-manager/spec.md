# Menu Bar Entry Separation

## Requirement: Ops Notch presentation is panel-specific
The Ops Notch status item MUST keep a stable identity independent of the real menu-bar visibility state.

### Scenario: Real menu bar changes state
- **WHEN** the real hidden menu-bar region changes between collapsed and expanded
- **THEN** Ops Notch keeps the same glyph and panel-oriented tooltip
- **AND** the Ops Notch click meaning does not become an expand/collapse action

## Requirement: `‹ / │` controls only the real menu bar
The persistent toggle MUST directly expand or collapse the real hidden menu-bar region.

### Scenario: User expands with `‹`
- **WHEN** the state is collapsed and the user left-clicks `‹`
- **THEN** the manager requests `.hiddenExpanded`
- **AND** it MUST NOT open the hidden-items proxy panel

### Scenario: User collapses with `│`
- **WHEN** the state is expanded and the user left-clicks `│`
- **THEN** the manager requests `.collapsed`
- **AND** it MUST NOT open or close the hidden-items proxy panel

## Requirement: Toggle remains reachable
The existing single-host geometry MUST continue to pin `‹ / │` at the visible edge while the host width changes for collapse, expansion, animation, or auto-hide.

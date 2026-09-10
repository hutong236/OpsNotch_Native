# Menu-bar hidden toggle specification

## Requirement: persistent reveal/collapse affordance

While menu-bar management is enabled, the normal hidden-area reveal/collapse affordance SHALL remain visible and clickable regardless of the hidden spacer width.

### Scenario: collapsed
Given the normal hidden area is collapsed, the system SHALL keep a fixed-width `‹` toggle visible next to Ops Notch while a separate spacer expands toward the hidden side.

### Scenario: expanded
Given the normal hidden area is visible, the same fixed-width toggle SHALL remain visible and display `│`.

## Requirement: separated responsibilities

The variable-width hidden spacer SHALL NOT be the interactive reveal/collapse control.

### Scenario: clicking Ops Notch
A normal left click on Ops Notch SHALL open only the hidden-items proxy panel and SHALL NOT change real menu-bar visibility.

### Scenario: clicking the persistent toggle
A normal left click on `‹ / │` SHALL toggle the real system menu-bar hidden area.

### Scenario: right-clicking the persistent toggle
A right click on `‹ / │` SHALL open the Ops Notch management menu.

## Requirement: geometry compatibility

AX section classification and notch-overflow geometry SHALL use the hidden spacer as the boundary, not the visible toggle.

## Requirement: upgrade compatibility

The visible toggle SHALL reuse the previous hidden-separator autosave key so existing users retain the established visible control position as closely as macOS allows.

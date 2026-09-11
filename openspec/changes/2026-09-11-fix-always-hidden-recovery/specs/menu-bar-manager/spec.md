# Menu Bar Manager: always-hidden recovery

## Requirement: explicit always-hidden reveal is real and stable

When the user explicitly chooses to show all menu-bar sections while the always-hidden section is enabled, the application MUST reveal the real system menu-bar sections and MUST NOT replace that action with the Hidden Items Panel.

### Scenario: recover an item from always-hidden

- Given a third-party menu-bar item is positioned in the always-hidden section
- And menu-bar management is enabled
- When the user chooses Show All
- Then the real always-hidden section remains visible
- And the Hidden Items Panel is closed
- And normal auto-hide is not scheduled for this reveal
- So the user can hold Command and drag the item back across the separator

## Requirement: latest explicit state wins

A delayed notch-overflow probe MUST NOT overwrite a visibility state explicitly selected after the probe started.

### Scenario: collapse while an overflow probe is pending

- Given a notch-overflow probe is waiting to finish
- When the user explicitly collapses or chooses another visibility state
- Then the previous probe is invalidated
- And its delayed result does not reopen the Hidden Items Panel or restore the older visibility state

## Requirement: ordinary hidden reveal keeps overflow protection

The normal hidden-section reveal MAY continue to redirect to the Hidden Items Panel when notch overflow is detected.

# Menu bar hidden toggle

## Requirement: internal spacer self-heals after visible toggle movement

When menu-bar management is enabled, the fixed `‹ / │` control SHALL remain an independent fixed-width status item. The variable-width hidden spacer SHALL be treated as an internal implementation detail.

Before applying hidden-section geometry, the app SHALL ensure the hidden spacer's preferred position follows the current preferred position of the fixed toggle on the hidden side. If the stored spacer position is stale, the app SHALL update and recreate the spacer without requiring the user to manipulate it.

User-facing ordering validation SHALL only reject arrangements that can be corrected by moving visible controls. A stale invisible spacer SHALL NOT by itself trigger the order-invalid alert.

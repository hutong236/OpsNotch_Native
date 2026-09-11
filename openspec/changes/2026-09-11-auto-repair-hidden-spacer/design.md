# Design

The visible fixed toggle and the variable-width hidden spacer remain separate `NSStatusItem`s. The fixed toggle is user-facing and Command-draggable; the spacer is internal.

The internal spacer must not be treated as a user-correctable ordering constraint. Before applying hidden-section geometry, compare the spacer's stored preferred position with the toggle's current stored preferred position. If stale, update the spacer preferred position to the slot immediately on the hidden side and recreate only the spacer status item so AppKit restores it at the corrected location.

Visible-order validation remains responsible for detecting real user-facing mistakes: the fixed toggle must be on the hidden side of Ops Notch, and the optional Always Hidden separator must remain on the hidden side of the fixed toggle. The invisible spacer is omitted from alert eligibility.

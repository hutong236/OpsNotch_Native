# Proposal: disable ordinary pointer hover activation

## Problem
The top Sensor should remain easy to hit during native drag/drop, but ordinary pointer movement should no longer open or alter the Shelf. The previous hover-intent tuning still leaves a behavior surface that can feel unpredictable in daily menu-bar use.

## Change
Remove ordinary pointer hover as a Shelf interaction path entirely:

- pointer enter/move/exit SHALL NOT expand, hide, or schedule the Shelf;
- remove hover intent geometry, delay, movement policy, callbacks, and timers;
- keep the native Sensor panel and drag/drop destination unchanged;
- keep Nearby drag assist behavior unchanged.

## Scope
- Sensor ordinary pointer interaction only.
- No change to drag payload parsing, file promises, storage, Nearby overlay geometry, or Shelf content.

Tracks #82.

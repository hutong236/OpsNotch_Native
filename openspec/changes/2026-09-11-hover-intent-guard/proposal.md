# Proposal: Guard shelf hover intent against accidental top-edge traversal

## Problem
The Sensor currently uses a large drag target and a comparatively eager hover path. Although drag/drop and ordinary mouse hover are already separate event paths, moving the pointer across the menu bar can still enter the hover tracking area long enough to expand the full Shelf unintentionally.

## Change
Keep the existing Sensor bounds for native drag/drop, but make ordinary hover activation deliberate:

- use a compact 100×8pt center activation strip on both notched and non-notched displays;
- accept hover intent only when the pointer enters through the lower edge of that strip, rejecting side traversal;
- require a 0.4s dwell;
- cancel the dwell when pointer travel exceeds 6pt;
- keep drag session recognition, Nearby assist, and drop destination bounds unchanged.

## Scope
- Sensor hover intent only.
- No change to drag payload parsing or storage semantics.
- No change to Nearby overlay geometry.

Tracks #79.

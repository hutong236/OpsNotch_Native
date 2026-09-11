# Proposal: Remove Top Sensor Indicator

## Why
Ordinary pointer hover has already been removed from the top Sensor, so the persistent dot/pill indicator no longer communicates an available mouse action. It also visually overlaps content near the top center of the display.

## What Changes
- Remove the persistent dot/pill indicator from `SensorView`.
- Remove indicator visibility state and geometry that exist only for drawing it.
- Keep the transparent Sensor panel dimensions and native drag/drop destination unchanged.
- Keep Nearby drag assist and all drop payload handling unchanged.

## Tracking
- GitHub issue: #85

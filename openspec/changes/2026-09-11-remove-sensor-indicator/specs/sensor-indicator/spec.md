# Sensor Indicator Specification

## Requirement: No idle visual indicator
The top Sensor MUST NOT draw a persistent dot, pill, ring, or other idle visual indicator.

### Scenario: Shelf hidden
Given the Shelf is hidden, when the user is not dragging content, then no Sensor indicator is visible at the top of the display.

### Scenario: Shelf visible
Given the Shelf is visible, then Sensor visibility callbacks MUST NOT toggle any idle indicator because no indicator exists.

## Requirement: Drag destination unchanged
The removal of the idle indicator MUST NOT change Sensor panel bounds, screen placement, registered pasteboard types, or native drag/drop behavior.

### Scenario: Valid drag enters Sensor
Given a supported file, URL, text, or file-promise drag, when it enters the existing Sensor bounds, then the existing Drop flow remains available.

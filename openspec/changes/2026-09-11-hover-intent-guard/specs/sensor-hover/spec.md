# Sensor hover intent specification

## Requirement: compact ordinary-hover activation area

Ordinary pointer hover SHALL use a dedicated 100×8pt center activation strip on supported displays while native drag/drop SHALL retain the full Sensor bounds.

### Scenario: ordinary pointer crosses the menu bar
Given the pointer enters the hover strip from the left or right side, the system SHALL NOT expand the Shelf.

### Scenario: deliberate upward approach
Given the pointer enters the strip through its lower edge and remains inside, the system SHALL begin hover-intent dwell evaluation.

## Requirement: dwell and movement guard

A valid ordinary-hover entry SHALL require approximately 0.4 seconds of stable dwell before expanding the Shelf.

### Scenario: stable dwell
Given a valid lower-edge entry and pointer travel stays within 6pt for the dwell duration, the system SHALL expand the Shelf.

### Scenario: continued movement
Given a pending hover intent and pointer travel exceeds 6pt, the system SHALL cancel that intent and SHALL NOT expand the Shelf until a new valid entry occurs.

### Scenario: pointer exits
Given a pending hover intent and the pointer leaves the activation strip, the system SHALL cancel the pending intent.

## Requirement: drag behavior remains independent

Native file, URL, text, and file-promise drag sessions SHALL continue to use existing Sensor drag/drop bounds and SHALL NOT depend on the ordinary-hover activation strip or dwell gate.

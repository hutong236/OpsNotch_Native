# Sensor pointer interaction specification

## Requirement: ordinary pointer movement is inert

Ordinary pointer enter, movement, dwell, and exit over the top Sensor SHALL NOT change Shelf visibility or schedule Shelf expansion/hiding.

### Scenario: pointer crosses the top edge
Given no native drag session is active, when the pointer crosses any part of the Sensor, the Shelf SHALL remain unchanged.

### Scenario: pointer dwells over the Sensor
Given no native drag session is active, when the pointer remains over the Sensor for any duration, the Shelf SHALL remain unchanged.

### Scenario: pointer exits the Sensor
Given no native drag session is active, pointer exit SHALL NOT schedule Shelf hiding or other Shelf state changes.

## Requirement: drag/drop remains available

Native file, URL, text, and file-promise drag sessions SHALL continue to use the existing Sensor bounds and drag/drop callbacks.

### Scenario: valid drag enters Sensor
When a readable native drag enters the Sensor, the existing Drop UI/handling SHALL continue to run.

### Scenario: Nearby assist active
When Nearby mode has already shown its drag target, the top Sensor SHALL remain a valid drop destination without showing duplicate Drop UI.

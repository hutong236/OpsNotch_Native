## ADDED Requirements

### Requirement: Clipboard duplicate suppression SHALL NOT retain a second full payload

Clipboard monitoring SHALL keep only bounded metadata needed for the short duplicate-suppression window rather than retaining the previous complete text or file-path payload.

#### Scenario: Large text is copied
- **WHEN** the system clipboard changes to a large text payload
- **THEN** Ops Notch captures the text using existing Shelf semantics
- **AND** ClipboardManager retains only a compact fingerprint for short-term duplicate suppression

### Requirement: Stale local searches SHALL stop promptly

Local file search SHALL avoid launching filesystem work for superseded keystrokes and SHALL propagate cancellation to already-started background searches.

#### Scenario: User types rapidly
- **WHEN** several query values replace each other within the debounce window
- **THEN** superseded queries exit without starting a directory scan
- **AND** a background scan that has already started observes cancellation during traversal and exits without publishing stale results

### Requirement: Existing clipboard capture responsiveness SHALL be preserved

The optimization SHALL NOT widen the configured clipboard polling intervals or remove the Sensor `catchIfChanged()` fallback.

#### Scenario: Shelf is visible or hidden
- **WHEN** ClipboardManager monitors `NSPasteboard.general.changeCount`
- **THEN** the existing active and idle polling intervals remain unchanged

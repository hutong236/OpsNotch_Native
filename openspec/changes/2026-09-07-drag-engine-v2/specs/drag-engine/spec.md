# Specification: Drag Engine V2

## Requirement 1 — Detect supported external drag sessions

The application SHALL recognize a supported drag initiated in another application using event-driven mouse-drag events and the system drag pasteboard, without introducing a periodic polling timer.

### Scenario: Finder file drag

- **Given** Ops Notch is running and no shelf window is open
- **When** the user starts dragging one or more files from Finder
- **Then** the drag assist session becomes active after the drag pasteboard exposes supported types
- **And** a nearby Drop Zone becomes visible on the display containing the pointer

### Scenario: Unrelated mouse drag

- **Given** the drag pasteboard has not changed for the current mouse gesture
- **When** the user moves a window, slider, or performs another ordinary mouse drag
- **Then** Ops Notch SHALL NOT show the Drop Zone solely because a mouse-drag event occurred

### Scenario: Drag pasteboard is late

- **Given** the first mouse-drag event arrives before the drag pasteboard is populated
- **When** later mouse-drag events for the same gesture observe a changed supported drag pasteboard
- **Then** Ops Notch SHALL recognize the session at that point
- **And** SHALL NOT use a timer to wait for the pasteboard

## Requirement 2 — Nearby Drop Zone

The application SHALL show a non-activating AppKit Drop Zone near the current pointer for recognized external drags.

### Scenario: Display placement

- **When** the Drop Zone is shown
- **Then** it SHALL be positioned on the `NSScreen` containing the pointer
- **And** its frame SHALL be clamped to that screen's visible frame
- **And** it SHALL flip to another side of the pointer when the preferred side has insufficient space

### Scenario: No focus theft

- **Given** the user starts a drag from another application
- **When** the Drop Zone becomes visible
- **Then** the source application SHALL remain frontmost/key as far as AppKit permits
- **And** the Drop Zone SHALL NOT call `makeKey` or require text focus

### Scenario: Cross-display drag

- **Given** a recognized drag is active
- **When** the pointer moves to another display
- **Then** the same Drop Zone SHALL migrate to the new display
- **And** there SHALL NOT be duplicate active Drop Zones on multiple displays

## Requirement 3 — Preserve the top Sensor fallback

The existing top Sensor SHALL continue to receive file, URL, and string drags even if Drag Assist cannot recognize or display the nearby target.

### Scenario: Drag Assist unavailable

- **Given** the global drag monitor cannot be installed or the session is not recognized
- **When** the user drags supported content into the existing Sensor
- **Then** the current Sensor drop workflow SHALL still add the content to Shelf

### Scenario: User moves from nearby target to Sensor

- **Given** the nearby Drop Zone is visible
- **When** the same drag enters the top Sensor
- **Then** the nearby Drop Zone SHALL hide
- **And** the existing Shelf drop presentation SHALL become the active destination

## Requirement 4 — Single coordinated drag state

All transient drag UI SHALL be controlled by one drag-session state machine.

### Scenario: Cancel before drop

- **Given** a recognized drag is active and the Drop Zone is visible
- **When** the drag ends without a successful Ops Notch drop
- **Then** all transient drag UI SHALL disappear
- **And** no Shelf item SHALL be created
- **And** the state SHALL return to idle

### Scenario: Successful drop

- **When** a supported payload is successfully accepted by either the nearby Drop Zone or top Sensor
- **Then** the payload SHALL be added exactly once
- **And** the existing success feedback SHALL be shown
- **And** the transient Drag Assist UI SHALL be dismissed after the configured feedback interval

### Scenario: Repeated callbacks

- **Given** AppKit sends repeated drag-update callbacks for the same session
- **Then** Ops Notch SHALL NOT create duplicate Shelf items or duplicate success transitions

## Requirement 5 — Resolve payloads in native priority order

The application SHALL use one shared AppKit payload resolver for Sensor and nearby Drop Zone.

### Scenario: File promise available

- **Given** the dragging pasteboard contains one or more `NSFilePromiseReceiver` objects
- **When** the user drops the content into Ops Notch
- **Then** file promises SHALL take precedence over lower-fidelity fallback representations
- **And** promised files SHALL be received asynchronously into an application-managed staging directory
- **And** only successfully received files SHALL be added to Shelf

### Scenario: Finder file URL

- **Given** the dragging pasteboard contains ordinary file URLs and no file promise takes precedence
- **When** the drop succeeds
- **Then** all valid file URLs SHALL be added using the existing file-path ingestion behavior

### Scenario: HTTP URL

- **Given** the dragging pasteboard contains an `http` or `https` URL
- **When** the drop succeeds
- **Then** the URL SHALL be captured as a URL Shelf item

### Scenario: Text

- **Given** the dragging pasteboard contains non-empty text that is not classified as an http/https URL
- **When** the drop succeeds
- **Then** the content SHALL be captured as Text

## Requirement 6 — File Promise lifecycle safety

Promised-file reception SHALL have explicit success, partial-success, failure, and cleanup behavior.

### Scenario: All promises succeed

- **When** every promised file is received successfully
- **Then** all received files SHALL be ingested into Shelf once
- **And** staging resources no longer required SHALL be cleaned according to the storage handoff design

### Scenario: Partial promise failure

- **When** some promised files succeed and others fail
- **Then** only successful files SHALL be ingested
- **And** diagnostics SHALL record counts, not content or paths

### Scenario: All promises fail

- **When** no promised file can be received
- **Then** no Shelf item SHALL be created
- **And** the UI SHALL leave the receiving state without becoming stuck

## Requirement 7 — Multi-display and display-change resilience

Drag Assist SHALL coexist with the existing per-display Sensor architecture.

### Scenario: External monitor disconnected during drag

- **Given** the active Drop Zone is on an external display
- **When** that display disappears
- **Then** Ops Notch SHALL either move the target to the current valid pointer display or cancel Drag Assist cleanly
- **And** the operating system's original drag SHALL remain unaffected

### Scenario: Spaces/full-screen

- **When** a supported drag occurs in another Space or a full-screen application
- **Then** the transient Drop Zone SHALL use collection behavior compatible with all Spaces/full-screen auxiliary presentation

## Requirement 8 — Default permission and performance behavior

Drag Engine V2 SHALL preserve the lightweight accessory-app behavior.

### Scenario: First run / upgrade

- **When** a user upgrades to the Drag Engine V2 build
- **Then** the default feature path SHALL NOT intentionally request Accessibility or Input Monitoring authorization

### Scenario: Idle application

- **Given** no external drag is occurring
- **Then** Drag Engine V2 SHALL NOT add a periodic drag-detection timer
- **And** no drag pasteboard contents SHALL be repeatedly read in the background

## Requirement 9 — Privacy-safe diagnostics

Drag diagnostics SHALL contain only operational metadata.

### Scenario: Logging a drop

- **When** a drag session is recognized, resolved, succeeds, or fails
- **Then** logs MAY include state, display ID, payload category, item counts, duration, and error category
- **But** SHALL NOT contain full file paths, URL bodies, or dragged text content

## Requirement 10 — Phase 3 outbound semantics

When the outbound phase is implemented, Shelf-to-Finder dragging SHALL follow native operation negotiation and shall not regress pin/unpin behavior.

### Scenario: Successful outbound drag

- **Given** a Shelf item is dragged to a valid destination
- **When** AppKit reports a successful drag operation
- **Then** post-drag Shelf behavior SHALL be decided from the final operation and item lock/pin state
- **And** an unsuccessful or cancelled drag SHALL never remove the item

### Scenario: Pinned item

- **Given** the item is pinned/locked
- **When** it is successfully dragged out
- **Then** it SHALL remain in Shelf

### Scenario: Regression protection

- **When** outbound semantics are changed
- **Then** repeated-copy and unpin behavior fixed by Issue #46 SHALL remain correct

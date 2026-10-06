# Ops Notch 3.0 Experience Architecture Design

Date: 2026-10-07
Status: Approved design baseline
Repository baseline: v2.8.5 / main @ 19d3dfef9e55951fdcc58c4478f6e00dbb1b6a4f

## 1. Objective

Ops Notch 3.0 is a full product-experience redesign, not a visual skin.

The goal is to transform the current collection of shelf, clipboard, Finder, desktop, preview, drag-and-drop, and settings features into one coherent macOS productivity product with an award-level quality bar comparable to Awwwards, Webby Awards, and FWA in craft, while preserving native macOS behavior, accessibility, reliability, and low idle cost.

The product should feel like a native "Spatial Command Shelf": users summon one surface, find or capture what they need, inspect it, and act without thinking about which subsystem owns the capability.

Core interaction model:

Capture -> Understand -> Recall -> Inspect -> Act

Success means:
- the main interaction is immediately understandable;
- mouse and keyboard flows are equally complete;
- system-level behavior remains native and predictable;
- visual hierarchy, spacing, typography, motion, and control states are consistent;
- the app remains quiet while idle and efficient over long-running sessions;
- existing user data and storage remain compatible;
- no critical regression is introduced in clipboard, drag/drop, Finder, desktop, preview, or multi-display behavior.

## 2. Non-goals

This redesign will not:
- replace the native AppKit sensor/drag/window system with SwiftUI gestures;
- move AppKit or SwiftUI dependencies into OpsNotchCore;
- add arbitrary shell, SSH, kubectl, or command execution;
- introduce machine-learning ranking in the first version;
- rewrite stable persistence solely for UI reasons;
- sacrifice accessibility or performance for visual effects;
- create a web-style interface that merely runs on macOS.

## 3. Product positioning

Ops Notch becomes one coherent command surface rather than separate tools.

Conceptual model:

- Capture: drag, clipboard, text, image, file, folder, URL
- Recall: search, smart recent, favorites, Finder paths, desktop/workspace
- Inspect: content preview, source, time, usage, semantic metadata
- Act: copy, open, reveal, preview, favorite, switch desktop, move window

The user should experience "the thing I need is here and the next action is obvious", not "this app has many different features".

## 4. Experience principles

### 4.1 Native first

AppKit continues to own system interaction:
- NSPanel and window lifecycle
- drag destinations and drag sessions
- status item
- pasteboard
- system services and workspace behavior

SwiftUI owns presentation and content composition.

### 4.2 Quiet by default

Idle state should not animate, glow, flash, or consume attention. Feedback appears only for a meaningful event:
- drag proximity
- capture
- summon
- success
- error

### 4.3 Search first

The main shelf is command-oriented. Search is the primary entry point for clipboard, favorites, Finder, desktop, workspace, and actions.

Persistent type-filter chips are removed from the main surface. Type filtering remains available through command/search syntax or a lightweight filter control.

### 4.4 Context without unpredictability

Context is used to rank useful items, but first-version ranking must be deterministic and testable.

No opaque ML ranking is introduced.

### 4.5 One visual language

Desktop, Finder, clipboard, files, URLs, apps, and actions all use the same row-state model and component system.

### 4.6 Stable space

Filtering and selection should preserve spatial continuity. Avoid large layout jumps, full-list replacement animation, or unnecessary motion.

## 5. Core interface states

The product uses five explicit presentation states plus hidden:

- hidden
- peek
- expanded
- dropTarget
- confirmation

These replace the current ambiguous model where "peek" is used as a success state.

### 5.1 Idle

No persistent visual noise. The notch/sensor remains available through native interaction.

### 5.2 Peek

Peek answers only: "what is here now?"

It may show:
- the most relevant current item;
- a compact count;
- a short contextual status.

It does not include search, filters, settings, or dense action controls.

### 5.3 Expanded

The primary working surface contains:

1. Command Bar
2. Smart Shelf
3. Inspector
4. Compact keyboard/status footer

### 5.4 Drop Target

During external drag, the surface expands toward the user with clear acceptance state and copy/reference intent where relevant.

### 5.5 Confirmation

Success feedback is a dedicated presentation state for messages such as:
- Saved
- Copied
- Added

Confirmation then resolves to hidden or expanded depending on keep-open state.

## 6. Main shelf information architecture

### 6.1 Command Bar

The top surface is a focused command/search entry.

It searches or resolves:
- clipboard history
- favorites
- stored shelf items
- Finder quick paths
- desktop commands
- workspace commands
- supported safe actions

Examples:
- d2 -> Desktop 2
- ~/Downloads -> Finder path intent
- type:file report -> file-filtered search
- @fav token -> favorites-oriented search

No arbitrary command execution is added.

### 6.2 Smart Shelf

The visible content is grouped by intent rather than by implementation source.

Primary groups:
- Context
- Now
- Favorites
- Recent
- Results

Groups are shown only when meaningful.

### 6.3 Inspector

The right side becomes a contextual inspector, not a passive preview pane.

Common structure:
- preview/content
- title
- source
- timestamp
- semantic metadata
- primary action
- secondary actions

Specialized inspectors may exist for:
- image
- text
- file/folder
- URL
- application/action

## 7. Unified shelf row

All major content types render through one presentation component.

A row consists of:
- icon/thumbnail
- title
- subtitle
- metadata
- optional semantic badge
- primary interaction
- limited secondary affordance

Required states:
- default
- hovered
- pressed
- focused
- selected
- disabled
- dragging

Keyboard focus and mouse hover must use the same visual language.

Hover should expose at most two direct secondary controls, typically:
- favorite/pin
- more

Additional actions belong in a contextual menu/popover.

## 8. Design system

Create a dedicated design-system layer under the app target.

Target structure:

Sources/OpsNotchApp/DesignSystem/
- OpsSpacing.swift
- OpsRadius.swift
- OpsTypography.swift
- OpsSurface.swift
- OpsMotion.swift
- OpsControlMetrics.swift
- OpsVisualState.swift
- OpsIconButton.swift

### 8.1 Spacing

Use a 4pt base rhythm with semantic tokens such as:
- micro
- xSmall
- small
- medium
- large
- xLarge

Business views should not invent arbitrary padding constants.

### 8.2 Radius

Use a small controlled hierarchy:
- small
- control
- card
- panel

### 8.3 Typography

Use semantic roles instead of many near-identical point sizes:
- display
- title
- heading
- body
- secondary
- metadata
- micro

Hierarchy should rely on weight, contrast, spacing, and grouping, not only tiny point-size changes.

### 8.4 Surface

Define a restrained elevation model:
- transparent/context
- panel glass
- interactive card
- selected/floating emphasis

Accent color is reserved for focus, selection, primary action, favorite state, and meaningful success/drag feedback.

### 8.5 Motion

Use semantic duration tokens:
- instant: pressed feedback
- quick: hover/filter
- standard: panel/inspector transitions
- expressive: notch/drop transitions

AppKit and SwiftUI should share the same motion language.

Reduce Motion must disable spatial transforms and use minimal fades.

## 9. State architecture

The current AppModel is overloaded with persistence, settings, search, selection, focus, Finder/Desktop derivation, snapshots, and action routing.

Refactor toward:

### AppModel

Owns durable application state and service coordination:
- persisted items
- persisted settings
- storage reload/update
- service wiring

### ShelfExperienceModel

Owns session/UI state:
- query
- current mode
- focus
- selection
- highlighted item
- current context
- transient feedback
- presentation-facing interaction state

### ShelfSnapshotProvider

Owns derived presentation data:
- smart ranking
- sections
- presentation item construction
- invalidation-driven snapshot caching

This separation ensures SwiftUI views consume presentation-ready state instead of deriving complex data in body.

## 10. Presentation abstraction

Current QuickShelfEntry is a useful source abstraction but still exposes source-specific view branching.

Introduce a presentation adapter that converts domain/source entries into a unified ShelfPresentationItem.

Conceptually:

Domain source -> adapter -> ShelfPresentationItem -> OpsShelfRow

ShelfPresentationItem should describe:
- stable id
- icon/thumbnail model
- title
- subtitle
- metadata
- badge
- primary action
- secondary actions
- preview/inspector capability
- accessibility description

Views should not need to know whether the row originated from Finder, Desktop, or ShelfItem except where a specialized inspector/action requires it.

## 11. Window and interaction architecture

### 11.1 ShelfWindowController

Narrow responsibility to:
- NSPanel ownership
- screen selection
- frame placement
- hosting
- show/hide
- key-window behavior

### 11.2 ShelfPresentationCoordinator

Own:
- hidden -> peek
- peek -> expanded
- drag -> dropTarget
- dropTarget -> confirmation
- confirmation -> hidden/expanded

### 11.3 ShelfKeyboardController

Own keyboard routing:
- up/down
- left/right
- enter
- space
- escape
- supported command shortcuts

This removes keyboard and transition responsibilities from the window controller.

## 12. Command resolution

Create CommandResolver for explicit command-like queries.

First-version supported resolution:
- Desktop commands
- Finder/path intent
- shelf search
- safe filters

Examples:
- d
- d2
- type:file
- @fav

Security boundary:
- no arbitrary shell execution
- no SSH execution
- no kubectl execution
- all existing safe-action validation remains mandatory

## 13. Settings redesign

Replace the current single long ScrollView with sidebar-based information architecture.

Sections:
- General
- Shelf
- Clipboard
- Finder
- Workspace
- Input Method
- Shortcuts
- Advanced

Settings redesign should initially preserve the existing persisted schema wherever practical.

Schema migration is not justified solely for visual organization.

## 14. Menu bar redesign

The status menu becomes a concise control center.

Expected scope:
- Open Shelf
- Clipboard Catch state/control when available
- Keep Shelf Open
- Settings
- Quit

The menu is not a second application surface and should not duplicate the main product.

## 15. Localization

Formal UI copy must be routed through Localization.swift.

Remove direct production UI patterns such as:
language == .zhCN ? "..." : "..."

Chinese and English should have equivalent structure and behavior.

## 16. Existing modules retained

The following are retained unless implementation uncovers a specific defect:

- OpsNotchCore
- ShelfStoreService
- SafeActionValidator
- ClipboardManager
- SensorManager
- QuickLookService
- ItemActionService
- LoginItemService
- InputMethodManager
- Desktop system controllers/services
- Finder system controllers/services
- drag payload resolution

These components encapsulate real macOS behavior and should not be rewritten for presentation reasons.

## 17. Modules to refactor

Primary refactor targets:

- ShelfView.swift: split into focused views/components
- AppModel.swift: separate durable state from experience state
- ShelfWindowController.swift: separate panel, keyboard, and presentation transitions
- SettingsWindowController.swift: new settings IA
- QuickShelfEntry.swift: add/replace with presentation abstraction
- StatusBarController.swift: simplify menu
- Desktop/Finder/Local/Shelf row implementations: unify presentation

## 18. Code and behavior to remove

After replacement is verified, remove:
- persistent main-surface filter chips
- duplicate row style implementations
- duplicate relative-time formatters
- business-view magic spacing/radius values
- direct bilingual ternaries in production UI
- "peek means success" compatibility semantics
- Image + onTapGesture controls that should be real accessible controls
- temporary compatibility helpers made obsolete by the new experience layer

Do not leave parallel old/new UI paths after final migration.

## 19. Performance constraints

v2.8.5 establishes a performance baseline that must not regress.

Required rules:
- no UI polling
- no per-frame ranking
- no expensive computation inside SwiftUI body
- no repeated filesystem scanning
- avoid repeated NSImage decoding/construction
- no uncontrolled animations
- preserve invalidation-driven snapshot computation
- remove timers/observers when no longer required
- keep idle CPU quiet

Long-running validation must include multi-hour behavior, not only launch-time responsiveness.

## 20. Accessibility

The redesign must support:
- keyboard-only operation
- VoiceOver labels for interactive controls
- Reduce Motion
- Increase Contrast where applicable
- Light and Dark appearance
- notch and non-notch Macs
- multiple displays
- full-screen Spaces
- Chinese and English

Visual polish is not accepted if it weakens accessibility.

## 21. Migration plan

The implementation is intentionally staged so the application remains runnable.

### Phase 0 — Regression baseline
- freeze v2.8.5 behavior as baseline
- add/confirm tests around snapshots, keyboard navigation, action routing
- create manual regression checklist for system behaviors

### Phase 1 — Design system
- add tokens and common control metrics
- migrate existing UI incrementally
- no intentional product behavior change

### Phase 2 — Unified components
- add OpsIconButton, OpsSearchField, OpsShelfRow, section/header/badge/empty-state/inspector shell
- adapt Finder, Desktop, Shelf items to unified row
- remove old rows only after parity

### Phase 3 — Experience state
- introduce ShelfExperienceModel
- introduce ShelfSnapshotProvider
- introduce presentation items/adapters
- reduce AppModel responsibility

### Phase 4 — Main Shelf 3.0
- command bar
- smart grouping
- new row states
- inspector
- new empty states
- remove persistent filter chips
- complete mouse/keyboard parity

### Phase 5 — Presentation and motion
- explicit presentation states
- presentation coordinator
- keyboard controller
- notch/drop/confirmation motion
- Reduce Motion validation

### Phase 6 — Settings/menu/localization
- sidebar settings IA
- concise menu
- complete UI localization cleanup

### Phase 7 — Award-level polish
- visual hierarchy
- optical alignment
- motion timing
- state transitions
- dark/light refinement
- accessibility polish

### Phase 8 — Performance and long-running QA
- idle CPU
- clipboard polling impact
- snapshot rebuild frequency
- SwiftUI redraw behavior
- NSImage allocations
- observer/timer lifecycle
- memory growth
- 8–24 hour running behavior

### Phase 9 — Release
Suggested sequence:
- v3.0.0-beta.1
- v3.0.0-beta.2 as needed
- v3.0.0-rc.1
- v3.0.0

RC allows only bug fixes, performance fixes, accessibility fixes, and polish.

## 22. Verification gates

Every phase must keep the repository runnable and pass the existing engineering gates:

- swift test
- swift build
- python3 scripts/static_checks.py
- packaging verification where relevant

Manual regression must cover:
- clipboard text/image capture and restore
- file/folder/text drag-in
- drag-out
- Finder quick paths
- Desktop switching
- window movement behavior
- Quick Look / floating preview
- pin / working set
- keep-open behavior
- hotkey summon
- multi-display
- full-screen Spaces
- notch/non-notch
- light/dark
- zh/en
- Reduce Motion

## 23. Quality gate

Internal target before v3.0 release:

- Visual hierarchy >= 9/10
- Consistency >= 9/10
- Motion >= 9/10
- Keyboard UX >= 9/10
- Mouse UX >= 9/10
- Native macOS feeling >= 9/10
- Accessibility >= 8.5/10
- Performance: no regression from v2.8.5 baseline
- Critical feature regressions: 0

"Functionally complete" is not the completion criterion. A component that visibly belongs to the old visual/interaction system is not considered finished.

## 24. Data safety and compatibility

The redesign must preserve user data.

Rules:
- keep shelf.json backward compatible;
- avoid schema changes unless required by behavior;
- never delete existing user fields merely for cleanup;
- any required migration must be reversible or safely backward-readable;
- presentation refactors must not alter stored data semantics.

The hierarchy of priorities is:
1. data safety
2. correct system behavior
3. accessibility
4. performance
5. interaction quality
6. visual polish

## 25. Completion definition

Ops Notch 3.0 is complete only when:
- all planned experience surfaces have migrated to the new design system;
- the old duplicate UI paths are removed;
- all automated gates pass;
- manual system-behavior regression is complete;
- long-running performance meets or exceeds v2.8.5;
- accessibility checks pass;
- visual and motion self-review passes the defined quality gate;
- beta/RC validation produces no critical regression.

The implementation must remain incremental and releasable throughout the migration rather than relying on a single large rewrite.

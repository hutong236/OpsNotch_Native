# Ops Notch 3.0 Experience Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Ops Notch 3.0 as a coherent native macOS Spatial Command Shelf while preserving v2.8.5 data compatibility, system behavior, accessibility, and long-running performance.

**Architecture:** Keep OpsNotchCore and existing macOS services stable. Introduce an app-level design system, a presentation adapter, a dedicated shelf experience-state layer, and explicit panel presentation coordination; migrate the existing Shelf/Settings/Menu surfaces onto those layers incrementally. Each phase must remain buildable and must pass the existing CI gates before the next phase begins.

**Tech Stack:** Swift 5.9, SwiftPM, macOS 13+, AppKit, SwiftUI, XCTest, existing native macOS frameworks and CI scripts only.

**Spec:** `docs/superpowers/specs/2026-10-07-opsnotch-3-experience-architecture-design.md`

## Global Constraints

- Minimum platform remains macOS 13.
- Swift toolchain remains Swift 5.9 compatible.
- AppKit owns system interaction and window lifecycle; SwiftUI owns content/presentation.
- `OpsNotchCore` remains free of AppKit and SwiftUI imports.
- Preserve `shelf.json` backward compatibility; do not delete existing user fields.
- Preserve `SafeActionValidator`; do not add arbitrary shell, SSH, kubectl, Terminal, or command execution.
- Preserve invalidation-driven Quick Shelf snapshot behavior; do not add UI polling or per-frame ranking.
- Preserve accessory-app behavior, native status item, multi-display sensors, drag destination behavior, Quick Look, login item, and current private-interoperability probes.
- All formal UI copy routes through `L10n.text`; no new production bilingual ternaries.
- Reduce Motion must remove spatial transforms and keep only minimal fades.
- Every phase must pass `swift test`, `swift build`, and `python3 scripts/static_checks.py` before merge.
- Phases that affect packaging or release must also pass `scripts/build_app.sh`, codesign verification, and archive verification.
- Manual acceptance remains required for multi-display, drag/drop, clipboard semantics, Spaces/window movement, focus return, appearance, language, and long-running behavior.

## Review Focus

1. **Legacy data:** an existing v2.8.5 `shelf.json` must load without migration loss and re-save without deleting unknown/legacy-supported fields. Task 1 and Task 8 pin compatibility tests.
2. **Keyboard/mouse parity:** the same highlighted row must expose equivalent default actions through Enter and pointer click, without focus loss or duplicate action dispatch. Tasks 6, 9, and 12 pin navigation/action tests.
3. **Long-running efficiency:** opening/closing the shelf repeatedly must not introduce timers, per-frame ranking, or repeated derived-state computation. Tasks 5, 8, 15, and 18 pin cache/static/performance checks.
4. **Reduce Motion / accessibility:** all panel transitions must collapse to non-spatial fades and all icon-only controls must expose labels. Tasks 3, 11, 13, and 17 own these checks.
5. **System edge cases:** multi-display, full-screen Spaces, layout changes, external drag, and focus return must retain current native behavior. Tasks 1, 11, 16, and 18 own manual acceptance updates.

---

## File Structure Map

### New app files

`Sources/OpsNotchApp/DesignSystem/`
- `OpsSpacing.swift` — semantic spacing tokens.
- `OpsRadius.swift` — semantic corner-radius tokens.
- `OpsTypography.swift` — semantic typography roles.
- `OpsSurface.swift` — panel/card/selection material and surface helpers.
- `OpsMotion.swift` — shared SwiftUI/AppKit motion durations and Reduce Motion behavior.
- `OpsControlMetrics.swift` — hit targets, control heights, inspector width, row metrics.
- `OpsVisualState.swift` — unified default/hover/pressed/focused/selected/disabled/dragging state.
- `OpsIconButton.swift` — accessible icon-only button.

`Sources/OpsNotchApp/Shelf/`
- `ShelfPresentationItem.swift` — presentation-ready row descriptor and action capabilities.
- `ShelfPresentationAdapter.swift` — converts current `QuickShelfEntry` values into presentation items.
- `ShelfExperienceModel.swift` — session UI state only.
- `ShelfSnapshotProvider.swift` — invalidation-driven section/presentation snapshot builder.
- `ShelfRootView.swift` — new top-level expanded/drop/peek/confirmation content switch.
- `ShelfCommandBar.swift` — primary search/command entry.
- `ShelfSectionView.swift` — section shell.
- `ShelfRow.swift` — unified visual row.
- `ShelfEmptyState.swift` — first-run and no-results empty states.

`Sources/OpsNotchApp/Shelf/Inspector/`
- `ShelfInspectorView.swift` — common inspector shell.
- `ImageInspectorView.swift`
- `TextInspectorView.swift`
- `FileInspectorView.swift`
- `URLInspectorView.swift`

`Sources/OpsNotchApp/Shelf/Presentation/`
- `ShelfPresentationState.swift`
- `ShelfPresentationCoordinator.swift`
- `ShelfKeyboardController.swift`

`Sources/OpsNotchApp/Settings/`
- `SettingsRootView.swift`
- `GeneralSettingsView.swift`
- `ShelfSettingsView.swift`
- `ClipboardSettingsView.swift`
- `FinderSettingsView.swift`
- `WorkspaceSettingsView.swift`
- `ShortcutSettingsView.swift`
- `AdvancedSettingsView.swift`

### New core/testable logic files

`Sources/OpsNotchCore/CommandResolver.swift` — pure command/query parsing with no execution.
`Sources/OpsNotchCore/ShelfSectionModel.swift` — pure section identity/order rules for Context/Now/Favorites/Recent/Results.
`Tests/OpsNotchCoreTests/CommandResolverTests.swift`
`Tests/OpsNotchCoreTests/ShelfSectionModelTests.swift`

### Existing files intentionally modified

- `Sources/OpsNotchApp/ShelfView.swift` — migrate content out, then delete obsolete duplicate implementations.
- `Sources/OpsNotchApp/AppModel.swift` — remove UI-session responsibilities after migration.
- `Sources/OpsNotchApp/QuickShelfEntry.swift` — remain source/domain bridge until presentation adapter is fully established.
- `Sources/OpsNotchApp/ShelfWindowController.swift` — narrow to NSPanel/screen/frame/hosting.
- `Sources/OpsNotchApp/SettingsWindowController.swift` — host new sidebar settings root.
- `Sources/OpsNotchApp/StatusBarController.swift` — simplify menu.
- `Sources/OpsNotchApp/Localization.swift` — add all new 3.0 copy.
- `Sources/OpsNotchApp/AppDelegate.swift` — wire experience model/coordinator/keyboard controller.
- `scripts/static_checks.py` — add architecture regressions that are safe to enforce textually.
- `VERIFY_ON_MAC.md` — replace obsolete visual acceptance with 3.0 acceptance while retaining system regressions.

---

# Phase 0 — Regression Baseline

### Task 1: Lock v2.8.5 behavioral baseline

**Files:**
- Modify: `Tests/OpsNotchCoreTests/ShelfSettingsCompatibilityTests.swift`
- Modify: `Tests/OpsNotchCoreTests/QuickShelfKeyboardNavigationTests.swift`
- Modify: `Tests/OpsNotchCoreTests/QuickShelfSnapshotTests.swift`
- Modify: `VERIFY_ON_MAC.md`

**Interfaces:**
- Consumes: existing `ShelfSettings`, `QuickShelfKeyboardNavigation`, `QuickShelfItemSnapshotBuilder`.
- Produces: regression assertions that all later phases must keep passing.

- [ ] **Step 1: Add failing compatibility/navigation regression cases**
  - Assert legacy settings JSON decodes with current defaults.
  - Assert left/right navigation preserves the current highlight when the destination section is empty.
  - Assert snapshot ordering preserves the newest-item rule and working-set de-duplication.

- [ ] **Step 2: Run baseline tests**
  - Run: `swift test`
  - Expected: existing tests pass; new tests either pass immediately because behavior is already correct or expose a real baseline defect that must be fixed before Phase 1.

- [ ] **Step 3: Update `VERIFY_ON_MAC.md` with a named “Ops Notch 3.0 regression baseline” section**
  - Preserve clipboard, drag/drop, Finder, desktop/window movement, focus return, multi-display, hotkey, Quick Look, Light/Dark, zh/en, and Reduce Motion checks.
  - Mark existing filter-chip-specific checks as “legacy baseline until Phase 4 replacement”, not deleted yet.

- [ ] **Step 4: Run repository gates**
  - Run: `swift test && swift build && python3 scripts/static_checks.py`
  - Expected: all PASS.

- [ ] **Step 5: Commit**
  - Commit message: `test: lock Ops Notch 3.0 regression baseline`

---

# Phase 1 — Design System

### Task 2: Add semantic layout and typography tokens

**Files:**
- Create: `Sources/OpsNotchApp/DesignSystem/OpsSpacing.swift`
- Create: `Sources/OpsNotchApp/DesignSystem/OpsRadius.swift`
- Create: `Sources/OpsNotchApp/DesignSystem/OpsTypography.swift`
- Create: `Sources/OpsNotchApp/DesignSystem/OpsControlMetrics.swift`
- Modify: `Sources/OpsNotchApp/ShelfView.swift`

**Interfaces:**
- Produces: `OpsSpacing`, `OpsRadius`, `OpsTypography`, `OpsControlMetrics` semantic constants consumed by all subsequent UI tasks.

- [ ] **Step 1: Define exact semantic APIs**
  - `OpsSpacing.micro/xSmall/small/medium/large/xLarge`
  - `OpsRadius.small/control/card/panel`
  - `OpsTypography.display/title/heading/body/secondary/metadata/micro`
  - `OpsControlMetrics.searchHeight/rowHeight/compactRowHeight/minimumHitTarget/inspectorWidth/footerHeight`

- [ ] **Step 2: Replace the highest-frequency magic metrics in `ShelfView.swift` with tokens**
  - Do not redesign layout yet; this is a behavior-neutral migration.

- [ ] **Step 3: Build**
  - Run: `swift build`
  - Expected: PASS with no layout API compile errors.

- [ ] **Step 4: Run all gates**
  - Run: `swift test && swift build && python3 scripts/static_checks.py`
  - Expected: PASS.

- [ ] **Step 5: Commit**
  - Commit message: `refactor: introduce Ops Notch design tokens`

### Task 3: Add surface, motion, visual-state, and accessible icon controls

**Files:**
- Create: `Sources/OpsNotchApp/DesignSystem/OpsSurface.swift`
- Create: `Sources/OpsNotchApp/DesignSystem/OpsMotion.swift`
- Create: `Sources/OpsNotchApp/DesignSystem/OpsVisualState.swift`
- Create: `Sources/OpsNotchApp/DesignSystem/OpsIconButton.swift`
- Modify: `Sources/OpsNotchApp/ShelfView.swift`
- Modify: `scripts/static_checks.py`

**Interfaces:**
- Produces:
  - `OpsMotion.duration(for:reduceMotion:)`
  - visual states `default/hovered/pressed/focused/selected/disabled/dragging`
  - `OpsIconButton` with mandatory accessibility label.

- [ ] **Step 1: Add a static-check failure for new raw `.onTapGesture` icon buttons under the new DesignSystem/Shelf directories**
  - Existing legacy occurrences outside migrated paths are temporarily allowed.

- [ ] **Step 2: Implement surface/motion/state/control primitives**
  - Motion tokens: instant, quick, standard, expressive.
  - Reduce Motion path returns near-zero spatial duration and uses opacity-only transitions.

- [ ] **Step 3: Migrate at least one existing icon-only Shelf action to `OpsIconButton`**
  - Verify tooltip and accessibility label are present.

- [ ] **Step 4: Run checks**
  - Run: `swift test && swift build && python3 scripts/static_checks.py`
  - Expected: PASS.

- [ ] **Step 5: Commit**
  - Commit message: `feat: add shared surface and motion system`

---

# Phase 2 — Unified Components

### Task 4: Introduce presentation-ready shelf items

**Files:**
- Create: `Sources/OpsNotchApp/Shelf/ShelfPresentationItem.swift`
- Create: `Sources/OpsNotchApp/Shelf/ShelfPresentationAdapter.swift`
- Modify: `Sources/OpsNotchApp/QuickShelfEntry.swift`

**Interfaces:**
- Consumes: `QuickShelfEntry`, `ShelfItem`, `SemanticKind`, current language.
- Produces:
  - `ShelfPresentationItem.ID`
  - `ShelfPresentationItem.primaryAction`
  - `ShelfPresentationItem.secondaryActions`
  - preview capability and accessibility text.

- [ ] **Step 1: Define the presentation item/action enums and adapter signatures**
  - Keep execution out of the descriptor; actions describe intent only.

- [ ] **Step 2: Add adapter coverage through compile-time exhaustive switching and targeted debug assertions**
  - Every current `QuickShelfEntry` case must map.
  - No stored data is changed.

- [ ] **Step 3: Build**
  - Run: `swift build`
  - Expected: PASS.

- [ ] **Step 4: Commit**
  - Commit message: `refactor: add unified shelf presentation model`

### Task 5: Add unified row, section, search, badge, and empty-state components

**Files:**
- Create: `Sources/OpsNotchApp/Shelf/ShelfCommandBar.swift`
- Create: `Sources/OpsNotchApp/Shelf/ShelfSectionView.swift`
- Create: `Sources/OpsNotchApp/Shelf/ShelfRow.swift`
- Create: `Sources/OpsNotchApp/Shelf/ShelfEmptyState.swift`
- Modify: `Sources/OpsNotchApp/ShelfView.swift`

**Interfaces:**
- Consumes: `ShelfPresentationItem`, DesignSystem tokens.
- Produces: reusable mouse/keyboard-neutral presentation components.

- [ ] **Step 1: Implement `ShelfRow(item:visualState:onPrimaryAction:onSecondaryAction:)`**
  - Ensure full-row primary interaction and maximum two direct hover accessories.
  - Use real `Button` semantics for controls.

- [ ] **Step 2: Migrate Finder row to the new component**
  - Existing Finder action behavior must remain unchanged.

- [ ] **Step 3: Migrate Desktop row**
  - Existing desktop command behavior must remain unchanged.

- [ ] **Step 4: Migrate persisted ShelfItem row**
  - Preserve copy/file pasteboard semantics, pin, preview, reveal, edit/remove.

- [ ] **Step 5: Remove obsolete duplicate row rendering after parity**
  - Do not remove source-entry types yet.

- [ ] **Step 6: Run gates**
  - Run: `swift test && swift build && python3 scripts/static_checks.py`
  - Expected: PASS.

- [ ] **Step 7: Commit**
  - Commit message: `feat: unify Quick Shelf row components`

---

# Phase 3 — Experience State

### Task 6: Add pure command resolver

**Files:**
- Create: `Sources/OpsNotchCore/CommandResolver.swift`
- Create: `Tests/OpsNotchCoreTests/CommandResolverTests.swift`

**Interfaces:**
- Produces:
  - `public enum CommandIntent: Equatable`
  - `public enum CommandResolver { public static func resolve(_ query: String) -> CommandIntent? }`
- Supported first-version intents: desktop list/switch, finder path intent, type filter, favorites filter.

- [ ] **Step 1: Write failing tests**
  - `d` -> desktop list.
  - `d2` and `d 2` -> desktop switch 2.
  - `~/Downloads` and absolute path prefix -> finder path intent.
  - `type:file report` -> file-filtered query with residual `report`.
  - `@fav token` -> favorites query with residual `token`.
  - `ssh root@host`, `kubectl ...`, and `rm ...` -> no executable command intent.

- [ ] **Step 2: Run targeted tests**
  - Run: `swift test --filter CommandResolverTests`
  - Expected: FAIL before implementation.

- [ ] **Step 3: Implement parser**
  - Parsing only; no AppKit/service calls.

- [ ] **Step 4: Run targeted and full tests**
  - Run: `swift test --filter CommandResolverTests && swift test`
  - Expected: PASS.

- [ ] **Step 5: Commit**
  - Commit message: `feat: add safe shelf command resolver`

### Task 7: Add pure section identity/order model

**Files:**
- Create: `Sources/OpsNotchCore/ShelfSectionModel.swift`
- Create: `Tests/OpsNotchCoreTests/ShelfSectionModelTests.swift`

**Interfaces:**
- Produces:
  - `public enum ShelfSectionKind: CaseIterable, Equatable`
  - deterministic order: context, now, favorites, recent, results.

- [ ] **Step 1: Write failing tests for ordering and empty-section omission**
- [ ] **Step 2: Run `swift test --filter ShelfSectionModelTests`; expect FAIL**
- [ ] **Step 3: Implement section model**
- [ ] **Step 4: Run targeted/full tests; expect PASS**
- [ ] **Step 5: Commit**
  - Commit message: `feat: define Smart Shelf section model`

### Task 8: Split session UI state and snapshot provider from AppModel

**Files:**
- Create: `Sources/OpsNotchApp/Shelf/ShelfExperienceModel.swift`
- Create: `Sources/OpsNotchApp/Shelf/ShelfSnapshotProvider.swift`
- Modify: `Sources/OpsNotchApp/AppModel.swift`
- Modify: `Sources/OpsNotchApp/AppDelegate.swift`
- Modify: `Sources/OpsNotchApp/ShelfView.swift`
- Modify: `Tests/OpsNotchCoreTests/QuickShelfSnapshotTests.swift`
- Modify: `Tests/OpsNotchCoreTests/ShelfSettingsCompatibilityTests.swift`

**Interfaces:**
- `ShelfExperienceModel` owns query, focus/highlight, selection, context, transient presentation state.
- `ShelfSnapshotProvider` exposes one invalidation-driven presentation snapshot per revision.
- `AppModel` retains durable items/settings/storage/service coordination.

- [ ] **Step 1: Add regression tests around existing snapshot ordering/cache semantics and legacy settings before moving call sites**
- [ ] **Step 2: Move session properties without changing external behavior**
- [ ] **Step 3: Move snapshot derivation into provider and keep single-revision caching**
- [ ] **Step 4: Rewire Shelf view and AppDelegate**
- [ ] **Step 5: Run `swift test && swift build && python3 scripts/static_checks.py`; expect PASS**
- [ ] **Step 6: Commit**
  - Commit message: `refactor: separate shelf experience state from app state`

---

# Phase 4 — Main Shelf 3.0

### Task 9: Replace filter-chip UI with command-first search

**Files:**
- Modify: `Sources/OpsNotchApp/Shelf/ShelfCommandBar.swift`
- Modify: `Sources/OpsNotchApp/Shelf/ShelfExperienceModel.swift`
- Modify: `Sources/OpsNotchApp/Shelf/ShelfSnapshotProvider.swift`
- Modify: `Sources/OpsNotchApp/ShelfView.swift`
- Modify: `Sources/OpsNotchApp/Localization.swift`
- Modify: `Sources/OpsNotchApp/ShelfWindowController.swift`
- Modify: `VERIFY_ON_MAC.md`

**Interfaces:**
- Consumes: `CommandResolver.resolve(_:)`.
- Produces: search-first command surface with hidden/explicit filter state, not persistent chips.

- [ ] **Step 1: Route query through CommandResolver before ordinary content filtering**
- [ ] **Step 2: Remove persistent type chips from the expanded UI**
- [ ] **Step 3: Remove obsolete `⌘1…⌘6` chip switching from the window key monitor**
- [ ] **Step 4: Preserve type filtering through command syntax and any lightweight filter affordance**
- [ ] **Step 5: Update macOS acceptance tests for command-first behavior**
- [ ] **Step 6: Run gates and commit**
  - Commit message: `feat: make Quick Shelf command-first`

### Task 10: Add Smart Shelf grouping

**Files:**
- Modify: `Sources/OpsNotchApp/Shelf/ShelfSnapshotProvider.swift`
- Modify: `Sources/OpsNotchApp/Shelf/ShelfSectionView.swift`
- Modify: `Sources/OpsNotchApp/ShelfView.swift`
- Modify: `Sources/OpsNotchApp/Localization.swift`
- Modify: `Tests/OpsNotchCoreTests/SmartShelfRankingTests.swift`

**Interfaces:**
- Uses existing `SmartShelfRanking`; does not introduce ML.
- Produces visible Context/Now/Favorites/Recent/Results sections only when meaningful.

- [ ] **Step 1: Add ranking regression tests ensuring explicit query relevance remains above context affinity**
- [ ] **Step 2: Build section snapshots from the single cached derived state**
- [ ] **Step 3: Render sections with unified row language**
- [ ] **Step 4: Verify newest-item, pin, working-set, use-count, and context semantics**
- [ ] **Step 5: Run gates and commit**
  - Commit message: `feat: group Smart Shelf by user intent`

### Task 11: Build contextual inspector

**Files:**
- Create: `Sources/OpsNotchApp/Shelf/Inspector/ShelfInspectorView.swift`
- Create: `Sources/OpsNotchApp/Shelf/Inspector/ImageInspectorView.swift`
- Create: `Sources/OpsNotchApp/Shelf/Inspector/TextInspectorView.swift`
- Create: `Sources/OpsNotchApp/Shelf/Inspector/FileInspectorView.swift`
- Create: `Sources/OpsNotchApp/Shelf/Inspector/URLInspectorView.swift`
- Modify: `Sources/OpsNotchApp/ShelfView.swift`
- Modify: `Sources/OpsNotchApp/Localization.swift`

**Interfaces:**
- Consumes: focused `ShelfPresentationItem`.
- Produces: preview + metadata + primary/secondary actions without duplicating execution logic.

- [ ] **Step 1: Create common inspector shell**
- [ ] **Step 2: Add image/text/file/URL specializations**
- [ ] **Step 3: Route inspector actions through the same action dispatcher used by rows**
- [ ] **Step 4: Add accessibility labels and Reduce Motion transitions**
- [ ] **Step 5: Remove obsolete legacy preview pane**
- [ ] **Step 6: Run gates and commit**
  - Commit message: `feat: add contextual Quick Shelf inspector`

### Task 12: Complete unified mouse/keyboard action routing

**Files:**
- Modify: `Sources/OpsNotchApp/Shelf/ShelfExperienceModel.swift`
- Modify: `Sources/OpsNotchApp/AppModel.swift`
- Modify: `Sources/OpsNotchApp/ShelfView.swift`
- Modify: `Tests/OpsNotchCoreTests/QuickShelfKeyboardNavigationTests.swift`
- Modify: `VERIFY_ON_MAC.md`

**Interfaces:**
- Produces one primary-action path per presentation item used by Enter and pointer activation.

- [ ] **Step 1: Add navigation tests for section boundaries and empty destinations**
- [ ] **Step 2: Refactor action routing so keyboard and mouse invoke the same intent**
- [ ] **Step 3: Verify file pasteboard semantics remain file URLs**
- [ ] **Step 4: Verify Finder/Desktop actions remain non-copy actions**
- [ ] **Step 5: Run gates and commit**
  - Commit message: `refactor: unify shelf keyboard and pointer actions`

---

# Phase 5 — Presentation and Motion

### Task 13: Introduce explicit presentation states and coordinator

**Files:**
- Create: `Sources/OpsNotchApp/Shelf/Presentation/ShelfPresentationState.swift`
- Create: `Sources/OpsNotchApp/Shelf/Presentation/ShelfPresentationCoordinator.swift`
- Modify: `Sources/OpsNotchApp/ShelfWindowController.swift`
- Modify: `Sources/OpsNotchApp/Shelf/ShelfRootView.swift`
- Modify: `Sources/OpsNotchApp/AppDelegate.swift`

**Interfaces:**
- States: hidden, peek, expanded, dropTarget, confirmation.
- Coordinator methods: `showPeek`, `showExpanded`, `showDropTarget`, `showConfirmation`, `hide`.

- [ ] **Step 1: Add new state type and transition coordinator without removing old entry points**
- [ ] **Step 2: Rewire drop success from legacy `peek` semantics to `confirmation`**
- [ ] **Step 3: Implement true read-only Peek**
- [ ] **Step 4: Migrate callers, then remove legacy state aliases**
- [ ] **Step 5: Verify Reduce Motion uses non-spatial transition path**
- [ ] **Step 6: Run gates and commit**
  - Commit message: `refactor: make shelf presentation states explicit`

### Task 14: Extract keyboard controller

**Files:**
- Create: `Sources/OpsNotchApp/Shelf/Presentation/ShelfKeyboardController.swift`
- Modify: `Sources/OpsNotchApp/ShelfWindowController.swift`
- Modify: `Sources/OpsNotchApp/AppDelegate.swift`
- Modify: `VERIFY_ON_MAC.md`

**Interfaces:**
- Consumes key events while expanded/editor-inactive.
- Produces navigation/action/focus intents; does not own panel geometry.

- [ ] **Step 1: Move key-code routing out of ShelfWindowController**
- [ ] **Step 2: Preserve modifier normalization, editor bypass, Space preview semantics, Tab search focus, Esc behavior**
- [ ] **Step 3: Build and run keyboard regression acceptance**
- [ ] **Step 4: Run gates and commit**
  - Commit message: `refactor: extract Quick Shelf keyboard controller`

### Task 15: Apply coherent panel/drop/confirmation motion

**Files:**
- Modify: `Sources/OpsNotchApp/ShelfWindowController.swift`
- Modify: `Sources/OpsNotchApp/Shelf/Presentation/ShelfPresentationCoordinator.swift`
- Modify: `Sources/OpsNotchApp/DesignSystem/OpsMotion.swift`
- Modify: `VERIFY_ON_MAC.md`
- Modify: `scripts/static_checks.py`

**Interfaces:**
- Uses only OpsMotion timing tokens.
- No timer-based animation loops.

- [ ] **Step 1: Replace raw panel durations with OpsMotion tokens**
- [ ] **Step 2: Implement idle->peek, peek->expanded, drag->dropTarget, dropTarget->confirmation, confirmation->hidden/expanded transitions**
- [ ] **Step 3: Add static check preventing new raw hard-coded animation durations in new presentation files**
- [ ] **Step 4: Run gates and manual Reduce Motion acceptance**
- [ ] **Step 5: Commit**
  - Commit message: `feat: unify Ops Notch panel motion`

---

# Phase 6 — Settings, Menu, Localization

### Task 16: Rebuild settings information architecture

**Files:**
- Create: `Sources/OpsNotchApp/Settings/SettingsRootView.swift`
- Create: `Sources/OpsNotchApp/Settings/GeneralSettingsView.swift`
- Create: `Sources/OpsNotchApp/Settings/ShelfSettingsView.swift`
- Create: `Sources/OpsNotchApp/Settings/ClipboardSettingsView.swift`
- Create: `Sources/OpsNotchApp/Settings/FinderSettingsView.swift`
- Create: `Sources/OpsNotchApp/Settings/WorkspaceSettingsView.swift`
- Create: `Sources/OpsNotchApp/Settings/ShortcutSettingsView.swift`
- Create: `Sources/OpsNotchApp/Settings/AdvancedSettingsView.swift`
- Modify: `Sources/OpsNotchApp/SettingsWindowController.swift`
- Modify: `Sources/OpsNotchApp/Localization.swift`
- Modify: `Tests/OpsNotchCoreTests/ShelfSettingsCompatibilityTests.swift`

**Interfaces:**
- Reuses existing persisted settings model; no schema change required for navigation.

- [ ] **Step 1: Add compatibility test asserting current settings encode/decode unchanged**
- [ ] **Step 2: Build sidebar/detail root**
- [ ] **Step 3: Move existing controls into semantic sections without changing their backing fields**
- [ ] **Step 4: Preserve Finder/Input Method/Workspace specialized controls**
- [ ] **Step 5: Run gates and manual settings regression**
- [ ] **Step 6: Commit**
  - Commit message: `feat: redesign Ops Notch settings navigation`

### Task 17: Simplify menu and complete localization cleanup

**Files:**
- Modify: `Sources/OpsNotchApp/StatusBarController.swift`
- Modify: `Sources/OpsNotchApp/Localization.swift`
- Modify: `Sources/OpsNotchApp/Shelf/**/*.swift`
- Modify: `Sources/OpsNotchApp/Settings/**/*.swift`
- Modify: `scripts/static_checks.py`

**Interfaces:**
- Menu scope: Open Shelf, Clipboard Catch state/control if implemented by existing setting/state, Keep Shelf Open, Settings, Quit.

- [ ] **Step 1: Simplify status menu without adding a second feature surface**
- [ ] **Step 2: Replace all new/modified direct bilingual ternaries with `L10n.text` keys**
- [ ] **Step 3: Add static check over migrated directories rejecting new `.zhCN ?` UI copy patterns**
- [ ] **Step 4: Verify zh/en layout and VoiceOver labels**
- [ ] **Step 5: Run gates and commit**
  - Commit message: `refactor: finish 3.0 menu and localization cleanup`

---

# Phase 7 — Award-Level Polish

### Task 18: Remove obsolete UI paths and perform design-quality pass

**Files:**
- Modify/Delete: obsolete sections in `Sources/OpsNotchApp/ShelfView.swift`
- Modify: all new DesignSystem/Shelf/Settings files as required by review
- Modify: `VERIFY_ON_MAC.md`
- Modify: `scripts/static_checks.py`

**Interfaces:**
- No new feature interface; this task removes parallel legacy implementations.

- [ ] **Step 1: Remove old filter-chip views, duplicate row views, duplicate relative-time helpers, legacy preview pane, and legacy peek-success compatibility code**
- [ ] **Step 2: Add static checks that migrated code uses DesignSystem tokens for row/panel radii and motion**
- [ ] **Step 3: Perform visual self-review against hierarchy, consistency, optical alignment, hover/pressed/focus/selected, inspector balance, dark/light, and empty states**
- [ ] **Step 4: Perform accessibility self-review for keyboard-only, labels, Reduce Motion, Increase Contrast**
- [ ] **Step 5: Run all gates**
  - Run: `swift test && swift build && python3 scripts/static_checks.py && scripts/build_app.sh`
  - Expected: PASS.

- [ ] **Step 6: Commit**
  - Commit message: `refactor: remove legacy Quick Shelf presentation paths`

---

# Phase 8 — Performance and Long-Running QA

### Task 19: Prove no regression from v2.8.5 performance architecture

**Files:**
- Modify: `Tests/OpsNotchCoreTests/SmartShelfRankingCacheTests.swift`
- Modify: `Tests/OpsNotchCoreTests/QuickShelfSnapshotTests.swift`
- Modify: `scripts/static_checks.py`
- Modify: `VERIFY_ON_MAC.md`

**Interfaces:**
- Existing invalidation/caching behavior remains authoritative.

- [ ] **Step 1: Add/extend cache tests proving repeated reads at the same revision do not rebuild derived state**
- [ ] **Step 2: Add static guards against new polling timers in Shelf/DesignSystem/Settings presentation code**
- [ ] **Step 3: Add manual telemetry checklist for idle CPU, snapshot rebuild rate, NSImage churn, observers, timers, and memory growth**
- [ ] **Step 4: Run full automated gates**
  - Run: `swift test && swift build && python3 scripts/static_checks.py`
  - Expected: PASS.

- [ ] **Step 5: Package app and run 8–24 hour acceptance on a Mac**
  - Record idle CPU/memory start/end and any recurring wake source.
  - If this environment cannot keep a Mac session alive for that duration, mark Phase 8 incomplete rather than claiming success; do not tag v3.0.0 final until a real run is supplied or completed by an available execution environment.

- [ ] **Step 6: Commit**
  - Commit message: `test: harden Ops Notch 3.0 performance regression gates`

---

# Phase 9 — Release

### Task 20: Beta release gate

**Files:**
- Modify: release notes/changelog location already used by repository, if any.
- No product-code change unless a release blocker is found.

**Interfaces:**
- Produces: `v3.0.0-beta.1` only after Phase 0–8 automated gates pass and required manual acceptance is at beta-ready level.

- [ ] **Step 1: Run release build and package verification**
  - Run: `scripts/build_app.sh`
  - Verify: `codesign --verify --deep --strict "build/Ops Notch.app"`
  - Verify archive extraction matches packaged app.

- [ ] **Step 2: Run the full updated `VERIFY_ON_MAC.md` beta checklist**
- [ ] **Step 3: Tag and publish `v3.0.0-beta.1`**
- [ ] **Step 4: Commit/release-note metadata if repository workflow requires it**

### Task 21: Release-candidate stabilization

**Files:**
- Only blocker-fix files plus release notes.

**Interfaces:**
- Produces: `v3.0.0-rc.1`.
- No new features.

- [ ] **Step 1: Fix only beta regressions, accessibility issues, performance issues, or visual polish defects**
- [ ] **Step 2: Re-run automated gates and affected manual acceptance**
- [ ] **Step 3: Publish `v3.0.0-rc.1`**

### Task 22: Final v3.0.0 release

**Files:**
- Release notes/changelog only unless a final blocker exists.

**Interfaces:**
- Produces final `v3.0.0`.

- [ ] **Step 1: Confirm all Phase 0–8 tasks are complete**
- [ ] **Step 2: Confirm critical regressions = 0**
- [ ] **Step 3: Confirm performance is not worse than v2.8.5, including the long-running acceptance requirement**
- [ ] **Step 4: Run final CI/release packaging**
- [ ] **Step 5: Merge final release branch to `main`**
- [ ] **Step 6: Tag and publish `v3.0.0`**
- [ ] **Step 7: Verify the published artifact installs/launches and matches the tagged commit**

---

## Phase Merge Strategy

Use one reviewable branch/PR per phase, based on the previous merged phase:

- `refactor/3.0-phase-0-baseline`
- `refactor/3.0-phase-1-design-system`
- `refactor/3.0-phase-2-components`
- `refactor/3.0-phase-3-experience-state`
- `refactor/3.0-phase-4-main-shelf`
- `refactor/3.0-phase-5-presentation-motion`
- `refactor/3.0-phase-6-settings-menu`
- `refactor/3.0-phase-7-polish`
- `refactor/3.0-phase-8-performance`
- `release/3.0`

Each phase:
1. starts from current `main`;
2. contains the phase tasks only;
3. runs CI;
4. gets reviewed;
5. merges before the next phase begins.

Do not stack all code on one giant unmerged branch.

## Completion Rule

The executor may continue from Phase 0 through Phase 9 without asking for feature-by-feature confirmation once this plan and execution method are approved. It must still stop rather than falsely claim completion when an objective gate cannot be performed, especially the 8–24 hour real-Mac performance acceptance or release artifact verification.

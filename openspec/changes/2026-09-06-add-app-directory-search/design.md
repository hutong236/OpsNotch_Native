# Design

## Approach
Add `ApplicationSearchService` in `OpsNotchApp`. It builds a cached list of `.app` bundles by enumerating only the three fixed application roots. Enumeration skips hidden files and application package descendants.

`AppModel.visibleLocalEntries` merges application matches with existing local file matches:
- All: application matches first, then local file matches
- Apps: application matches only
- Files: local file matches only

Applications reuse `QuickShelfEntry.local` and the existing Local Results row, preserving the current UI and keyboard navigation without introducing a second search panel.

## Activation
`AppModel` detects `.app` paths in local entries and launches them with `NSWorkspace.openApplication`. Successful launch hides the shelf; failures surface a toast.

## Constraints
No Spotlight APIs, shell commands, or scanning outside the configured fixed roots.

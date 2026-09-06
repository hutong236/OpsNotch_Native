# Application directory search

## Requirements

### Fixed search roots
The application search MUST inspect only `/Applications`, `/System/Applications`, and `~/Applications`. It MAY recurse into subdirectories of those roots but MUST NOT search outside them.

### Matching
When the search query is non-empty, application results MUST match the application bundle name using case-insensitive contains matching.

### Filters
Application results MUST appear in the All and Apps filters and MUST NOT appear in the Files filter.

### Activation
Pressing Enter on or clicking an application result MUST launch that `.app` bundle via macOS workspace APIs.

### Existing behavior
Finder entries and clipboard/file retrieval behavior MUST remain unchanged.

# Add fixed-directory application search

## Why
Quick Shelf already provides a unified keyboard search flow, but installed applications can only be used after they have been manually added to the shelf.

## What changes
- Search installed `.app` bundles from three fixed roots only:
  - `/Applications`
  - `/System/Applications`
  - `~/Applications`
- Match application names by case-insensitive contains.
- Reuse existing Local Results rows and Quick Shelf keyboard navigation.
- Enter/click launches an application instead of copying its path.
- Application results participate in the existing All and Apps filters.
- Generic file search excludes `.app` bundles so applications are handled by the application search path.

## Out of scope
- Spotlight or full-disk search
- Configurable application roots
- Background filesystem watching

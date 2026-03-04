---
status: complete
created: 2026-03-04
completed: 2026-03-04
---
Add `LSApplicationCategoryType` metadata for the macOS app target to eliminate archive warnings about missing app category.

## Acceptance Criteria
- `Shilling` target build settings include `INFOPLIST_KEY_LSApplicationCategoryType`.
- `make app-release` completes without the "No App Category is set" warning.

---
status: complete
created: 2026-03-04
completed: 2026-03-04
---
Stop tracking Xcode user data in git by enforcing ignore rules and removing tracked `xcuserdata` paths from version control.

## Acceptance Criteria
- `.gitignore` explicitly ignores Xcode `xcuserdata`.
- No tracked files remain under any `xcuserdata` path.

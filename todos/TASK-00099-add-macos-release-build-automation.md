---
status: complete
created: 2026-03-04
completed: 2026-03-04
---
Add a repo-owned script and Makefile targets to produce a local `Shilling.app` release archive deterministically.

## Acceptance Criteria
- `scripts/build-macos-app.sh` runs `xcodebuild archive` for scheme `Shilling` with configurable output paths.
- `Makefile` exposes local release build/install targets that call the script.
- `docs/project-overview.md` documents the automated workflow.

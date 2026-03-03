---
status: ready
created: 2026-03-03
---

# Add CI And Lock Dependencies

Context: repository has no CI workflow and dependency resolution is not locked in version control.

Acceptance criteria:
- add CI workflow(s) that run `swift test` for `ShillingCore` and app build checks
- track `ShillingCore/Package.resolved` in git and stop ignoring lock state needed for reproducibility
- ensure CI uses deterministic dependency resolution
- document local/CI verification commands in project docs

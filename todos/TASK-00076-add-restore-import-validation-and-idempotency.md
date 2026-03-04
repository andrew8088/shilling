---
status: ready
created: 2026-03-04
---

# Add Restore Import Validation And Idempotency

Context: restore operations are high risk and must fail safely.

Acceptance criteria:
- implement restore pipeline with schema-version checks and referential integrity validation
- support dry-run preview with counts and blocking validation errors
- ensure repeated restore of the same package does not duplicate records unexpectedly
- define behavior for conflict resolution when restoring into non-empty stores

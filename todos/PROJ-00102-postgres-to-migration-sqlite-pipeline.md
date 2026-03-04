---
status: complete
created: 2026-03-04
completed: 2026-03-04
tasks:
  - TASK-00103-build-postgres-to-migration-sqlite-exporter.md
  - TASK-00104-document-migration-format-and-runbook.md
---
Deliver a deterministic export pipeline from the legacy Postgres database into a migration SQLite format that can be imported into Shilling safely.

## Acceptance Criteria
- Export pipeline produces a migration SQLite file with source-fidelity and target-ready tables.
- Export is deterministic and idempotent for a fixed source snapshot.
- Validation checks (counts and balancing invariants) are included.

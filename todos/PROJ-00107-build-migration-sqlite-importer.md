---
status: ready
created: 2026-03-04
tasks:
  - TASK-00108-implement-migration-sqlite-importer-via-modelcontext.md
---
Build a migration importer that reads `target_*` tables from the migration SQLite file and persists data into Shilling using `ModelContext`.

## Acceptance Criteria
- Importer consumes migration SQLite produced by `scripts/export-legacy-postgres-to-migration-sqlite.py`.
- Import path writes through Shilling domain/services and `ModelContext` (no direct SQL writes into SwiftData internals).
- Import run validates core invariants (balanced transactions, entry cardinality, referential integrity of mapped IDs).
- Import process is documented with deterministic run/verify commands.

---
status: complete
created: 2026-03-04
completed: 2026-03-04
---
Implement a migration SQLite importer that reads `target_accounts`, `target_transactions`, `target_entries`, and related `target_*` tables, then persists equivalent Shilling models via `ModelContext` in deterministic order.

## Acceptance Criteria
- CLI/script entrypoint accepts migration SQLite input path and target Shilling data path.
- Import order is deterministic and safe for relationships (accounts before transactions/entries, dependent entities after parents).
- Importer enforces transaction invariants and fails fast on invalid source rows.
- Integration verification demonstrates imported row counts and balancing checks match migration SQLite expectations.
- Relevant docs are updated with importer usage and operational checks.

---
status: complete
created: 2026-03-04
completed: 2026-03-04
---
Build a script that exports legacy Postgres data into a migration SQLite database with deterministic transforms for accounts, transactions, entries, budgets, and import records.

## Acceptance Criteria
- Script accepts source DB and output SQLite path parameters.
- Script creates schema and inserts transformed rows in one transactional run.
- Script emits validation summary and non-zero exit on invariant failures.

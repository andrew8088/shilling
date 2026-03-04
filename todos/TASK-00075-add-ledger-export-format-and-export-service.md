---
status: ready
created: 2026-03-04
---

# Add Ledger Export Format And Export Service

Context: backups require a stable schema and deterministic export behavior.

Acceptance criteria:
- define a versioned export format covering accounts, transactions, entries, budgets, and import records
- implement export service that emits deterministic output for identical datasets
- include metadata for app version, export timestamp, and schema version
- provide compatibility hooks for future schema migrations

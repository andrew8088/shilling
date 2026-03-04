---
status: ready
created: 2026-03-04
---
Context: legacy `imports`, `import_rows`, and `import_mappings` include parsing config and staged-row history that current `ImportRecord` cannot capture.

Acceptance criteria:
- extend import-domain models to preserve import status, parse configuration, and staged-row payloads
- support linking imported ledger rows back to staged source rows for audit/debug/revert workflows
- define retention and size-control policy for raw import payload storage

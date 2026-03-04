---
status: ready
created: 2026-03-04
tasks:
  - TASK-00075-add-ledger-export-format-and-export-service.md
  - TASK-00076-add-restore-import-validation-and-idempotency.md
  - TASK-00077-add-backup-and-restore-entrypoints-in-app-and-cli.md
  - TASK-00078-add-backup-restore-tests-and-runbook.md
---

# Backup Export And Restore

Context: local-first finance data needs first-class portability and disaster recovery.

Acceptance criteria:
- app supports full-ledger export to a documented portable format
- restore flow validates input, previews impact, and prevents accidental destructive merges
- backup/restore is available in both app and CLI workflows
- child tasks include integrity tests and operational docs for safe recovery

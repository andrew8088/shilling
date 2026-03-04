---
status: ready
created: 2026-03-04
tasks:
  - TASK-00055-add-entry-clear-and-reconcile-state.md
  - TASK-00056-build-reconciliation-service-and-diff-calculation.md
  - TASK-00057-add-account-reconciliation-ui-flow.md
  - TASK-00058-add-reconciliation-tests-and-docs.md
---

# Reconciliation Workflow

Context: balances are hard to trust at month-end without a statement reconciliation workflow.

Acceptance criteria:
- users can mark imported or manual entries as cleared and reconciled against statement dates
- app supports account-level reconciliation sessions with target statement balance and computed difference
- reconciliation outcomes are persisted and visible in account register workflows
- child tasks include service coverage tests and docs updates

---
status: ready
created: 2026-03-04
---

# Add Entry Clear And Reconcile State

Context: reconciliation needs persisted entry-level lifecycle states.

Acceptance criteria:
- extend ledger models with cleared/reconciled state and statement-date metadata required for reconciliation
- preserve backward compatibility for existing stores and imported transactions
- expose clear/reconcile metadata through service-layer APIs used by UI and CLI
- no existing transaction or balance behavior regresses for unreconciled data

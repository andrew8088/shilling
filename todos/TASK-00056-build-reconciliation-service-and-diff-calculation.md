---
status: ready
created: 2026-03-04
---

# Build Reconciliation Service And Diff Calculation

Context: reconciliation logic should be isolated from UI and reusable across app and CLI.

Acceptance criteria:
- add a reconciliation service that computes cleared balance, statement balance difference, and completion status
- support beginning, updating, and finalizing a reconciliation session per account and statement date
- prevent finalization when unresolved differences remain unless explicitly forced by workflow rules
- return deterministic results for identical account snapshots and statement inputs

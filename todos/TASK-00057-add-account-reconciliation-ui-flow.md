---
status: ready
created: 2026-03-04
---

# Add Account Reconciliation Ui Flow

Context: users need a guided workflow in account detail to reconcile against a statement.

Acceptance criteria:
- add a reconciliation entry point from account detail with statement date and ending balance input
- register view supports toggling cleared state for eligible entries within the active reconciliation session
- UI shows live difference-to-target and blocks completion while out of balance
- successful reconciliation updates entry state and surfaces completion feedback in the account view

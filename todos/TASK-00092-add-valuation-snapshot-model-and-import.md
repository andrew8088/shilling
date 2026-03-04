---
status: blocked-by-TASK-00097-validate-demand-for-deferred-fidelity-features.md
created: 2026-03-04
---
Context: legacy `valuations` represent absolute account-value checkpoints that are not equivalent to normal journal transactions.

Acceptance criteria:
- add a valuation snapshot model tied to accounts and effective dates
- import legacy valuation kinds (including reconciliation/opening anchor) into the new model
- ensure reports can consume snapshots without corrupting transaction-ledger balances

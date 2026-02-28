---
status: ready
created: 2026-02-28
---

# Transaction Service

Service for creating, editing, and validating transactions.

## Work
- `TransactionService` operating on a `ModelContext`
- Create transaction with entries — validate that debits == credits, at least 2 entries, no zero amounts
- Edit transaction (update entries, re-validate)
- Delete transaction (cascades to entries)
- Fetch transactions with filtering (by date range, account, payee)
- Opening balance helper: create a transaction against the Opening Balances equity account

## Acceptance Criteria
- Creating a balanced transaction succeeds
- Creating an unbalanced transaction throws a descriptive error
- All validation rules covered by tests
- Opening balance creation tested

---
status: complete
created: 2026-02-28
completed: 2026-03-02
---

# Transaction UI

## Work
- Transaction list view with date, payee, and total amount
- Filtering by date range, account, payee search
- Create/edit transaction form:
  - Date picker, payee text field, notes
  - Dynamic entry rows: account picker + amount + debit/credit toggle
  - Validation feedback (shows imbalance amount)
  - "Simple mode": just pick from-account, to-account, and amount (creates 2 entries automatically)
- Delete transaction with confirmation

## Acceptance Criteria
- Simple mode covers 90% of daily use (quick expense entry)
- Full split mode available for complex transactions (mortgage payments)
- Validation prevents saving unbalanced transactions

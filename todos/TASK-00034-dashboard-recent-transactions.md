---
status: complete
created: 2026-03-03
completed: 2026-03-03
---

# Dashboard: Recent Transactions Section

Section at the bottom of the dashboard showing the most recent transactions.

## Work

- Query last 10 transactions sorted by date descending
- Display as a compact list using `TransactionRow` (or a slimmer variant)
- "View All" link at bottom that navigates to the full Transactions view
- Section header: "Recent Transactions"

## Acceptance Criteria

- Shows up to 10 most recent transactions
- Empty state if no transactions exist
- "View All" navigates to Transactions view (updates sidebar selection)
- Reuses existing `TransactionRow` or a simplified version

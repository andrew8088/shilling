---
status: ready
created: 2026-03-03
tasks:
  - TASK-00031-dashboard-layout.md
  - TASK-00032-dashboard-net-worth-card.md
  - TASK-00033-dashboard-budget-summary.md
  - TASK-00034-dashboard-recent-transactions.md
---

# Dashboard View

Replace the empty "Welcome to Shilling" landing state with a dashboard that shows the user's financial overview at a glance. This becomes the default selection when the app launches.

See `docs/origin-gap-analysis.md` §2 for rationale.

Depends on: PROJ-00025 (design system).

## Acceptance Criteria

- Dashboard is the default selected view when no account/section is chosen
- Shows net worth hero number (assets − liabilities)
- Shows account summary cards grouped by type with totals
- Shows current month budget health (total budgeted vs total spent)
- Shows last 5–10 recent transactions
- Quick action buttons: New Transaction, Import CSV
- Uses design system tokens throughout
- Responsive to window resizing

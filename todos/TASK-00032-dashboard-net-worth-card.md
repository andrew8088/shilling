---
status: ready
created: 2026-03-03
---

# Dashboard: Net Worth Card

Hero card at the top of the dashboard showing net worth.

## Work

- Compute net worth: sum of asset account balances − sum of liability account balances
- Display as a large `AmountText` with `largeTitle` style
- Label: "Net Worth" above the number
- Below: compact row showing total assets and total liabilities as secondary text
- Use `CardView` container

## Acceptance Criteria

- Net worth computed correctly from current account balances via `BalanceService`
- Handles zero/negative net worth gracefully
- Updates live when underlying data changes (SwiftData observation)

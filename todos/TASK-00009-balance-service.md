---
status: ready
created: 2026-02-28
---

# Balance Service

Compute account balances from entries.

## Work
- Balance for a single account (respecting debit-normal vs credit-normal)
- Balance as of a specific date
- Balances for all accounts (for balance sheet / net worth)
- Running balance for an account's transaction history (for account register view)

## Acceptance Criteria
- Asset account: debits increase balance, credits decrease
- Liability account: credits increase balance, debits decrease
- Date-filtered balances tested
- Running balance computation tested

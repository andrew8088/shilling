---
status: ready
created: 2026-02-28
---

# Seed Data / First-Run Setup

On first launch, seed the data store with essential accounts.

## Work
- Detect empty data store (no accounts exist)
- Create default accounts:
  - **Equity**: Opening Balances
  - **Expense**: Interest (for mortgage interest tracking)
- Optionally offer a "starter chart of accounts" with common categories:
  - Assets: Chequing, Savings
  - Liabilities: Credit Card, Mortgage
  - Expenses: Groceries, Dining, Transport, Utilities, Housing, Entertainment, Interest
  - Income: Salary, Other Income
- This should be a service method callable from both app and CLI

## Acceptance Criteria
- First-run detection works
- Default accounts created correctly
- Running seed twice is idempotent (doesn't duplicate)

---
status: ready
created: 2026-03-03
---

# Fix Budget Net Spend Semantics

Context: monthly budget actuals currently count only expense debits and ignore credits/refunds.

Acceptance criteria:
- `BudgetService.actualSpending` computes net expense movement for the month (debits minus credits)
- budget comparison values and remaining amount reflect net spending
- add/adjust tests for purchase + refund scenarios in `ShillingCore/Tests/ShillingCoreTests/BudgetServiceTests.swift`
- update any UI assumptions that rely on old spend semantics

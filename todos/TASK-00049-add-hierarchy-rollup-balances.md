---
status: complete
created: 2026-03-03
completed: 2026-03-04
---

# Add Hierarchy Rollup Balances

Context: parent account totals in dashboard/sidebar ignore descendant account entries.

Acceptance criteria:
- add a balance computation path that includes descendant accounts
- sidebar type totals and dashboard account totals use rollup balances for parent accounts
- preserve existing non-rollup behavior where explicitly needed
- add tests for multi-level account hierarchies in balance-related test suites

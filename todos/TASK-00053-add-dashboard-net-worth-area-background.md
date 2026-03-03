---
status: complete
created: 2026-03-03
completed: 2026-03-03
---

# Add Dashboard Net Worth Area Background

Context: dashboard users need historical context while scanning the headline net worth figure.

Acceptance criteria:
- dashboard net worth card renders a subtle area chart behind the large net worth value
- trend data comes from `ReportService.netWorthHistory` and covers a recent rolling period
- chart has no axis chrome and remains visually secondary to net worth, assets, and liabilities text
- app builds successfully after the change

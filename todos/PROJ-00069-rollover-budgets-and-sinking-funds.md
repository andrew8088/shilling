---
status: ready
created: 2026-03-04
tasks:
  - TASK-00070-extend-budget-model-with-rollover-policy.md
  - TASK-00071-implement-rollover-and-available-to-spend-calculations.md
  - TASK-00072-add-rollover-and-sinking-fund-controls-to-budget-ui.md
  - TASK-00073-add-rollover-budget-tests-and-docs.md
---

# Rollover Budgets And Sinking Funds

Context: monthly budget targets alone are too shallow for annual and irregular expense planning.

Acceptance criteria:
- budgets support rollover policy options and carryover amount behavior across months
- users can model sinking funds with target amount/date and available-to-spend calculations
- budget UI surfaces carryover, contribution, and remaining target progress clearly
- child tasks include coverage for rollover math and docs for budgeting semantics

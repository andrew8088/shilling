---
status: complete
created: 2026-03-03
completed: 2026-03-03
---

# Budget View Redesign

Upgrade the budget view from raw-number list to a visual dashboard.

Depends on: PROJ-00025 (design system), specifically TASK-00029 (`ProgressBar` component).

## Work

- Add summary row at top: total budgeted, total spent, total remaining with overall `ProgressBar`
- Replace `BudgetRow` text-only layout with:
  - Account name (subheading)
  - `ProgressBar` showing spent/target ratio
  - Below bar: "spent / target" text (caption) and remaining amount with `AmountText`
- Color coding via `ProgressBar` gradient (green → yellow → red)
- Apply design system typography, spacing, and `CardView` containers
- Keep existing month navigation and "Set Target" / "Copy Previous" toolbar actions

## Acceptance Criteria

- Summary card at top with overall progress
- Each budget row has a visual progress bar
- Progress bar colors match threshold logic (>80% → yellow, >100% → red)
- Layout uses design system tokens throughout
- Existing functionality preserved (month nav, set target, copy previous)

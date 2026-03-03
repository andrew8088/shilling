---
status: complete
created: 2026-03-03
completed: 2026-03-03
---

# Dashboard: Budget Summary Card

Card showing overall budget health for the current month.

## Work

- Query all budget targets for the current month
- Compute totals: total budgeted, total spent, total remaining
- Display as a `CardView` with:
  - "Budget — [Month Year]" header
  - Overall `ProgressBar` (spent / budgeted)
  - Text row: spent / budgeted (e.g., "$1,234 of $2,000")
  - Remaining amount with sign coloring
- Tap/click navigates to the full Budget view

## Acceptance Criteria

- Shows current month by default
- Progress bar colors correctly (green → yellow → red)
- Handles no budget targets gracefully (shows "No budget set" with link to create one)
- Tapping navigates to Budget view (updates sidebar selection)

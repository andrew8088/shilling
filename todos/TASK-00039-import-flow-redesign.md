---
status: ready
created: 2026-03-03
---

# Import Flow Redesign

Polish the CSV import wizard with design system tokens.

Depends on: PROJ-00025 (design system).

## Work

- Apply design system colors, typography, and spacing throughout all 4 steps
- Style step indicators / progress breadcrumbs at the top
- Use `CardView` for the CSV preview table container
- Style the result step with `AmountText`-style coloring for success/error counts
- Ensure button bar uses consistent styling

## Acceptance Criteria

- All 4 steps use design system tokens
- Visual step indicator shows progress (step 1 of 4, etc.)
- Existing functionality preserved
- Min frame size unchanged

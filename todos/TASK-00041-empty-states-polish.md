---
status: ready
created: 2026-03-03
---

# Empty States Polish

Upgrade empty states across all views to be more helpful and visually consistent.

Depends on: PROJ-00025 (design system).

## Work

- Update `EmptyStateView` to use design system tokens (colors, type scale, spacing)
- Add contextual call-to-action buttons to empty states:
  - No accounts → "Create Account" button
  - No transactions → "Create Transaction" or "Import CSV" buttons
  - No budget targets → "Set Budget Target" button
  - Dashboard with no data → guided first-step message
- Ensure icons use the `textTertiary` color from design system

## Acceptance Criteria

- All empty states have actionable CTAs (not just informational text)
- Consistent styling using design system tokens
- CTA buttons open the relevant creation sheet/flow

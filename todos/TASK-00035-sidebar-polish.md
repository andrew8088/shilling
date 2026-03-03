---
status: complete
created: 2026-03-03
completed: 2026-03-03
---

# Sidebar Polish

Improve the sidebar with design system tokens and additional information density.

Depends on: PROJ-00025 (design system), TASK-00031 (dashboard nav item).

## Work

- Add account type totals as trailing text on each disclosure group header (e.g., "Assets  $12,340")
- Add subtle SF Symbol icons per account type (banknote, creditcard, building.columns, arrow.down.circle, cart)
- Style account balances with `AmountText` component
- Apply design system typography and spacing
- Ensure Dashboard nav item is visually distinct (top of sidebar, not in a section)

## Acceptance Criteria

- Each account type group shows the sum of its account balances in the header
- Icons are subtle (secondary color, small) — not distracting
- Balances use sign-based coloring from `AmountText`
- Spacing and fonts use design system tokens

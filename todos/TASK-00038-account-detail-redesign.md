---
status: ready
created: 2026-03-03
---

# Account Detail View Redesign

Polish the account detail view with design system tokens and improved layout.

Depends on: PROJ-00025 (design system).

## Work

- Restyle header: account name (title), type badge (styled chip), balance as `AmountText` with `largeTitle` style
- Wrap header in `CardView`
- Register table: apply design system typography, use `AmountText` for amounts/running balance
- Apply consistent spacing from spacing scale
- Add "Archived" badge using design system warning color

## Acceptance Criteria

- Header is visually prominent with clear hierarchy
- Amounts use `AmountText` with consistent sign coloring
- Layout uses design system tokens (spacing, type, colors)
- Existing toolbar actions and functionality preserved

---
status: ready
created: 2026-03-03
---

# Dashboard Layout & Navigation

Set up the dashboard as the default detail view and wire it into sidebar navigation.

## Work

- Add `.dashboard` case to `NavigationItem` enum
- Make it the default selection on launch (instead of nil/welcome state)
- Add "Dashboard" item at top of sidebar (above account groups), with `house` or `chart.bar.xaxis` icon
- Create `DashboardView` scaffold with `ScrollView` containing placeholder sections:
  - Net worth card (placeholder)
  - Account summary section (placeholder)
  - Budget summary card (placeholder)
  - Recent transactions section (placeholder)
  - Quick actions row
- Quick actions: "New Transaction" and "Import CSV" buttons, styled with design system

## Acceptance Criteria

- Launching the app shows the dashboard by default
- Sidebar has Dashboard as first item, always visible (not inside a disclosure group)
- Dashboard scrolls vertically, cards use `CardView` from design system
- Quick actions open the same sheets as existing toolbar buttons

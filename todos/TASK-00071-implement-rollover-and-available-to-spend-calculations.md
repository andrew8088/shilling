---
status: ready
created: 2026-03-04
---

# Implement Rollover And Available To Spend Calculations

Context: budget reports need deterministic math for carryover and contribution tracking.

Acceptance criteria:
- implement month-to-month carryover computation using configured policy
- compute available-to-spend and remaining values that include carryover and current spend
- support sinking-fund contribution tracking against target amount and target date
- expose calculation outputs for dashboard, budget view, and report surfaces

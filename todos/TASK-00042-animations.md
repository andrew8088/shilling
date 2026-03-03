---
status: ready
created: 2026-03-03
---

# Subtle Animations & Transitions

Add microinteractions to key state changes for perceived quality.

Depends on: all view redesign tasks (do this last).

## Work

- Budget progress bars: animate fill on appear and value change
- Dashboard cards: subtle fade-in on appear
- Sidebar balance updates: animate number changes
- Transaction list filter changes: animate list updates with `.animation(.default)`
- Sheet presentations: ensure smooth transitions (mostly system default)

## Acceptance Criteria

- Animations are subtle (0.2–0.3s, ease-in-out) — never flashy or distracting
- No animation on first paint that blocks content visibility
- Performance: no jank on lists with 100+ items

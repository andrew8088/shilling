---
status: ready
created: 2026-03-02
---

# Spacing & Layout Constants

Define spacing and layout constants for consistent use across all views.

## Spacing Scale (8pt grid)

```
Spacing.xxs = 4
Spacing.xs  = 8
Spacing.sm  = 12
Spacing.md  = 16
Spacing.lg  = 20
Spacing.xl  = 24
Spacing.xxl = 32
```

## Layout Constants

- `cardCornerRadius` = 10
- `cardPadding` = Spacing.md (16)
- `sectionSpacing` = Spacing.xl (24)
- `listRowInsets` = Spacing.sm (12) horizontal, Spacing.xs (8) vertical

## Acceptance Criteria

- Constants defined in a `Spacing` / `Layout` enum or struct
- Used via `Spacing.md` syntax (not magic numbers)

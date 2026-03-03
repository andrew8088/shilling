---
status: complete
created: 2026-03-02
completed: 2026-03-03
---

# Reusable Styled Components

Create shared styled components that use the design tokens.

## Components

### `CardView`
A container with surface background, corner radius, optional subtle border. Wraps any content.

```swift
CardView {
    // content
}
```

### `AmountText`
Displays a `Decimal` formatted as currency with sign-based coloring:
- Positive → `.positive` color
- Negative → `.negative` color
- Zero → `.textSecondary`

Uses monospaced digits. Supports optional `style` parameter for size (`.title`, `.body`, etc.).

### `SectionHeader`
Styled section header with title, optional subtitle (e.g., total), and optional action button.

### `ProgressBar`
Horizontal progress bar with configurable fill color and background. Used for budget tracking.
- Takes `value` (0.0–1.0) and optional `color` override
- Default color: green → yellow → red based on value

## Acceptance Criteria

- All components defined in `Shilling/Views/Shared/`
- Each component has SwiftUI previews
- Components compose the color/type/spacing tokens defined in earlier tasks

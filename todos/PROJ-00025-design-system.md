---
status: ready
created: 2026-03-02
tasks:
  - TASK-00026-color-tokens.md
  - TASK-00027-type-scale.md
  - TASK-00028-spacing-and-layout.md
  - TASK-00029-styled-components.md
---

# Design System

Establish a design system for Shilling: color tokens, type scale, spacing grid, and reusable styled components. Everything else in the UI redesign builds on this.

See `docs/origin-gap-analysis.md` §1 for rationale.

## Acceptance Criteria

- Color tokens defined as SwiftUI `Color` extensions: background, surface, text (primary/secondary/tertiary), semantic (positive/negative/warning/info), accent
- Type scale defined as `Font` extensions or `ViewModifier`s: largeTitle, title, heading, subheading, body, caption — with consistent sizes and weights
- Spacing constants: 4, 8, 12, 16, 20, 24, 32pt scale
- Reusable `CardView` container with consistent padding, corner radius, and optional border
- Reusable `AmountText` view that formats a Decimal with sign-based coloring (green positive, red negative, secondary zero)
- Existing views migrated to use the new tokens (can be done incrementally in per-view redesign tasks)

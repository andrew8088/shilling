---
status: complete
completed: 2026-03-03
created: 2026-03-03
---

# Swift Charts Integration

Add the Swift Charts framework dependency and create chart helper utilities for use across report views.

Depends on: PROJ-00025 (design system) for color tokens.

## Work

- Import `Charts` framework in the Xcode project (it's a system framework, no SPM needed)
- Create chart color helpers that map to design system tokens:
  - Positive/income series → `.positive` color
  - Negative/expense series → `.negative` color
  - Neutral series → `.info` color
- Create a `ChartCard` wrapper: `CardView` + title + chart content + optional legend
- Verify Charts builds on macOS 14+ (our minimum target)

## Acceptance Criteria

- `import Charts` works in the Xcode project
- `ChartCard` component renders a chart inside a styled card with title
- Color helpers produce correct semantic colors for financial data
- Previews demonstrate a sample bar chart and line chart

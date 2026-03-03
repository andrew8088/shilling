---
status: complete
created: 2026-03-02
completed: 2026-03-03
---

# Type Scale

Define a consistent typographic scale as SwiftUI `Font` helpers or `ViewModifier`s.

## Scale

| Name | Size | Weight | Use |
|---|---|---|---|
| `largeTitle` | 28pt | semibold | Dashboard hero numbers |
| `title` | 22pt | semibold | View titles |
| `heading` | 17pt | medium | Section headers |
| `subheading` | 15pt | medium | Card titles, row primaries |
| `body` | 14pt | regular | Default text |
| `caption` | 12pt | regular | Metadata, timestamps |
| `label` | 10pt | medium | Badges, tags, chart labels |

All financial numbers should additionally use `.monospacedDigit()`.

## Acceptance Criteria

- Scale defined as `Font` extensions (e.g., `Font.shillingTitle`)
- Documented with a `TypeScalePreview` showing all levels
- Consistent with macOS HIG proportions (these are desktop sizes, not mobile)

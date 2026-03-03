---
status: complete
created: 2026-03-02
completed: 2026-03-03
---

# Color Tokens

Define the app color palette as SwiftUI `Color` extensions in a `Theme` or `Colors` namespace.

## Tokens

- `background` — primary window background
- `surface` — card/container background (slightly elevated)
- `surfaceSecondary` — nested container background
- `textPrimary`, `textSecondary`, `textTertiary`
- `positive` — green, for income/credits/good budget status
- `negative` — red, for expenses over budget/debits/negative balances
- `warning` — yellow/amber, for budget nearing limit
- `info` — blue, for neutral informational highlights
- `accent` — primary brand accent color
- `border` — subtle border/divider color

Use `Color(light:dark:)` or asset catalog to support light + dark mode from the start. Light mode is primary.

## Acceptance Criteria

- All tokens defined and documented in code comments
- A `ThemePreview` SwiftUI preview that shows all colors as swatches for visual verification
- No existing views need to change yet — that's a separate task

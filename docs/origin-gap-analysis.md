# Origin Gap Analysis — Shilling vs Origin UX

Companion to `docs/origin-research.md`. Written 2026-03-02.

---

## Current Shilling UI Summary

- **Navigation:** `NavigationSplitView` with sidebar (accounts grouped by type + quick links) and detail pane
- **Window:** 900×600 default, 700×400 minimum
- **Styling:** System defaults — secondary colors for metadata, red for negatives, monospaced digits for amounts
- **Typography:** Ad-hoc: `.title`, `.title2`, `.title3`, `.body`, `.caption` — no systematic scale
- **Spacing:** Ad-hoc: mix of 8pt and 12pt padding, no grid system
- **Colors:** System semantic colors only — no custom palette, no accent system
- **Data viz:** None — budget shows raw numbers, no charts or progress indicators
- **Empty states:** Basic `EmptyStateView` (icon + title + message) — functional but generic
- **Landing state:** Blank "Welcome to Shilling" when nothing selected — wasted space

---

## Gap Analysis

### 1. No Design System (HIGH IMPACT)

**Origin:** Consistent color palette, type scale, spacing grid, card components, semantic financial colors.
**Shilling:** No design tokens. Colors, fonts, and spacing are inline and inconsistent.

**Recommendation:** Create a design system with:
- Color tokens: background, surface, text primary/secondary/tertiary, semantic (positive/negative/warning/info)
- Type scale: largeTitle, title, heading, body, caption — mapped to specific sizes and weights
- Spacing scale: 4, 8, 12, 16, 20, 24, 32 (8pt grid)
- Reusable card/container component with consistent padding, corner radius, and border
- Amount display component with automatic sign coloring

**Effort:** Medium. **Impact:** Transforms every view immediately.

### 2. No Dashboard / Overview (HIGH IMPACT)

**Origin:** Net-worth-centric dashboard as the home screen — shows the most important number up front, with budget progress, recent transactions, and account summaries below.
**Shilling:** Empty "select something" state. Users must navigate to a specific account or transaction list to see anything.

**Recommendation:** Create a dashboard view as the default selection:
- Net worth hero number (assets − liabilities, computed from balances)
- Account summary cards grouped by type with totals
- Budget health: current month overall spent/remaining
- Recent transactions (last 5–10)
- Quick actions: new transaction, import CSV

**Effort:** Medium. **Impact:** Completely changes first impression and daily utility.

### 3. No Data Visualization (HIGH IMPACT)

**Origin:** Multiple chart types (bar, stacked bar, donut, Sankey, line, waterfall). Copilot Money uses Swift Charts.
**Shilling:** Zero charts. Budget shows numbers in a list. No trends, no progress bars, no visual indicators beyond color-coded "remaining" text.

**Recommendation:** Adopt Swift Charts. Priority visualizations:
- Budget progress bars (horizontal, per category) — simple, huge UX win
- Net worth line chart over time (PROJ-00022)
- Spending by category donut/bar (PROJ-00021)
- Cash flow bar chart (PROJ-00023)

**Effort:** Medium-High. **Impact:** Makes the app feel like a real finance tool vs a data entry form.

### 4. Budget View Lacks Visual Progress (MEDIUM IMPACT)

**Origin:** Budget categories show visual progress (spent vs target), 6-month trend, overall health indicator.
**Shilling:** `BudgetRow` shows account name, budget amount, actual, remaining — as raw text with color coding (green/yellow/red). No progress bars, no trends, no overall summary.

**Recommendation:**
- Add horizontal progress bar per budget row (filled portion = spent/target)
- Color gradient: green → yellow → red as percentage increases
- Add summary row at top: total budgeted, total spent, total remaining
- Add sparkline or mini bar chart showing last 3–6 months trend per category

**Effort:** Low-Medium. **Impact:** Budget view goes from "spreadsheet" to "dashboard."

### 5. Transaction List Missing Filters (LOW-MEDIUM IMPACT)

**Origin:** Filter by category, account, date range, merchant, amount range. Automatic categorization with manual override.
**Shilling:** Search text + single account picker + clear button. No date range, no amount filter.

**Recommendation:**
- Add date range picker (from/to)
- Add amount range filter (min/max)
- These two cover 80% of the filtering gap
- Skip merchant filter (we don't have merchants as a concept)

**Effort:** Low. **Impact:** Makes transaction list actually useful for investigation.

### 6. Sidebar Needs Polish (LOW-MEDIUM IMPACT)

**Origin:** Dashboard-centric navigation, tab-based sections, clean grouping.
**Shilling:** Sidebar with disclosure groups per account type, running balances. Functional but visually plain — standard `List` with system styling.

**Recommendation:**
- Add account type totals (sum of balances per group) in section headers
- Add subtle account type icons
- Add a "Dashboard" item at the top (above accounts) as default selection
- Consider showing mini sparkline next to each account (stretch goal)

**Effort:** Low. **Impact:** Incremental polish.

### 7. No Onboarding / First-Run Experience (LOW IMPACT)

**Origin:** Guided onboarding, progressive disclosure.
**Shilling:** Auto-seeds sample data on first launch. No guidance.

**Recommendation:** Skip for now — sample data is fine for a self-hosted tool. Revisit if we ever ship to others.

### 8. No Animations / Transitions (LOW IMPACT)

**Origin:** Smooth transitions, microinteractions, toast notifications.
**Shilling:** System default SwiftUI animations only.

**Recommendation:** Add `.animation(.default, value:)` to key state changes (budget bar fill, balance updates, list filtering). Subtle, not flashy.

**Effort:** Low. **Impact:** Adds perceived quality.

---

## Features Origin Has That We Don't Need

| Origin Feature | Why Skip |
|---|---|
| AI financial advisor | Out of scope — we're a bookkeeping tool |
| Investment tracking / portfolio | Not in our domain |
| Estate planning / will | Not in our domain |
| Tax filing | Not in our domain |
| Subscription management | Not in our domain |
| Partner mode | Single-household, no auth — not needed |
| Bank feed sync (Plaid) | We use CSV import; bank feeds are a future consideration |
| Market briefings | Not in our domain |

## Features We Should Adopt (Mapped to Our Domain)

| Origin Feature | Shilling Equivalent |
|---|---|
| Net worth dashboard | Sum of asset accounts − sum of liability accounts (we compute this natively) |
| Spending by category | Spending by expense account (our accounts ARE categories) |
| Budget progress bars | Visual bars on existing budget targets |
| Cash flow reports | Income accounts vs expense accounts over time |
| Sankey diagram | Stretch goal — shows money flow between account types |
| Multiple report viz types | Per-report chart type selection |
| Transaction filtering | Date range + amount range on existing list |
| Account type totals | Section header sums in sidebar |

---

## Priority Stack (20% effort → 80% impact)

1. **Design system** — colors, type, spacing, card component. Everything else builds on this.
2. **Dashboard view** — net worth + budget summary + recent transactions. Transforms the app.
3. **Budget progress bars** — lowest-effort, highest-visual-impact single change.
4. **Swift Charts integration** — unlocks all report views.
5. **Transaction filters** — date range + amount. Quick win.
6. **Sidebar polish** — type totals, icons, dashboard nav item.
7. **Report views** — build on Swift Charts. Already ticketed (PROJ-00021–00024).
8. **Animations** — sprinkle in last.

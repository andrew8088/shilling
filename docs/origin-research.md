# Origin (useorigin.com) — UI/UX Research

Research date: 2026-03-02. Sources listed at bottom.

## What Origin Is

Origin is an all-in-one personal finance platform: budgeting, spending tracking, net worth, investments, cash flow reports, estate planning, tax filing, and AI-powered financial advice. Named "Best Budgeting App" by Forbes (July 2024). Priced at $12.99/mo or $99/yr. Available on iOS, Android, web, and macOS.

Not a double-entry bookkeeping tool — it's single-entry with automatic categorization via Plaid-connected bank feeds. Our domain is fundamentally different but the visual language is what we're studying.

---

## Design Language

### Overall Aesthetic

Origin's design is described consistently across reviews as **minimalist, clean, and calming**. Reviewers contrast it with Monarch Money's "colorful graphs" — Origin opts for restraint. "Nothing feels too busy or overwhelming" despite the breadth of features.

Key principles:
- **Generous whitespace** — lets financial data breathe
- **Subdued color palette** — no loud gradients or busy illustrations
- **Clear visual hierarchy** — important numbers are large and prominent, metadata is secondary
- **Light + dark mode** — both first-class, described as having a "calmer interface"
- **Information density balanced with clarity** — lots of data on screen, but never overwhelming

### Color Palette

**Marketing site (dark theme):**
- Backgrounds: #000000, #131313, #222222, #363636, #404040
- Text: #fafafa (primary), #ffffff99 (secondary/muted)
- Borders: #5b5b5b
- Accents: white with varying opacity (rgba 255,255,255 at 0.24, 0.5)

**App interface (light theme):**
- White/off-white backgrounds
- "Cool shades of green and blue that draw the eye to important information"
- Functional color: green (positive/income), red (negative/expenses), blue (neutral/informational)
- Couples feature: user-selectable accent colors to distinguish "yours" vs "theirs"

**Translation for Shilling:** We should build a light-first color system with semantic financial colors (green/red) and generous use of muted grays for secondary information. Dark mode as a follow-up.

### Typography

- **Display/headings:** "Lyondisplay" — a serif display face, weight 300, line-height 135%
- **Body:** "Suisseintl" — a grotesque sans-serif (similar to SF Pro or Inter)
- **Data/numbers:** "Roboto Mono" — monospaced, weights 300–700
- **Scale:** H1 48px → H2 32px → H3 26px → body 14px → small 12px → label 10px

**Translation for Shilling:** We already use `.monospacedDigit()` for amounts — good. We should establish a clear type scale using SF Pro (system font) with consistent heading sizes. Consider SF Mono for financial data tables.

### Spacing & Layout

- 8px base unit implied (padding values: 8, 12, 16, 20, 24)
- Card padding: 20px internal
- Form field gaps: 16px
- Section spacing: 24px vertical
- Container max-width: 1400px
- Cards: 8–14px border-radius

**Translation for Shilling:** Adopt an 8pt grid system. Our current spacing is ad-hoc (12pt here, 8pt there). Systematize it.

---

## Navigation & Information Architecture

### Dashboard (Home Screen)

The redesigned dashboard is "a smarter home screen that puts budgets, accounts, and insights front and center." It's organized around **holistic Net Worth** as the central metric. Content blocks:

1. **Net Worth summary** — the hero number, prominent at top
2. **Account connections** — linked accounts grouped by type (bank, credit, investments, equity, real estate)
3. **Latest transactions** — recent spending for quick insight
4. **Budget progress** — current month tracking
5. **Portfolio performance** — investment returns at a glance
6. **Insights / "For You"** — AI-generated personalized recommendations

Key pattern: **summary → drill-down**. Dashboard shows the headline number; tap/click to see detail.

### Navigation Model

Tab-based with clearly labeled sections:
- Dashboard/Home
- Spending (transactions, budgets, reports)
- Investing
- Advice (forecasting, planning)
- Accounts (settings, security)

### Partner Mode

Toggle between "yours, theirs, and ours" views. Each partner connects their own accounts; shared dashboard shows combined view. Color-coded per partner.

**Translation for Shilling:** We don't need partner mode, but the sidebar → dashboard → detail drill-down pattern is exactly right. Our sidebar already groups accounts by type. We need a dashboard/overview as the default landing rather than a blank "select something" state.

---

## Key Screens & Patterns

### Transaction List

- Filterable by: category, account, date range, merchant, amount range
- Automatic categorization with manual override
- Editable fields: date, amount, description, merchant
- Split transaction support
- Memo/notes per transaction
- CSV import for manual entry
- "Everything Else" category surfaces uncategorized transactions

**Translation for Shilling:** Our transaction list has search + account filter. We could add: date range filter, category (account) filter, amount range. The "uncategorized" surface pattern doesn't apply to double-entry (every transaction has accounts by definition), but filtering by specific expense accounts is the equivalent.

### Budget View

- AI recommends initial budget based on historical spending
- Two-click budget setup and customization
- Monthly tracking: income vs expense, "in sync" indicator
- 6-month spending trend analysis (income, spending, buffer)
- One-time budgets for specific occasions
- Per-category progress tracking

**Translation for Shilling:** Our budget view shows targets vs actuals per account per month. We should add: trend over time (last 6 months), visual progress bars per category, overall budget health indicator.

### Reports / Data Visualization

Origin offers multiple visualization types per report context:

| Report Type | Available Visualizations |
|---|---|
| Cash Flow | Stacked bar, side-by-side bar, **Sankey diagram** |
| Expenses | Stacked bar, **donut/pie chart** |
| Income | Bar chart |
| Transfers | Waterfall chart (money-in vs money-out) |

Filtering on all reports: timeframe, accounts, categories, merchants, amount thresholds.

Reports are described as "super clean and easy to read" with the ability to pick visualization method.

**Translation for Shilling:** This maps well to our planned report tickets (PROJ-00021 through 00024). We should prioritize:
- Budget vs Actual: stacked or grouped bar chart
- Net Worth: line chart over time (already planned)
- Cash Flow: consider Sankey as a stretch goal, start with bar chart
- Balance Sheet: table format is fine, this is a point-in-time snapshot

### Net Worth

- Line graph showing wealth progression over time
- Assets vs liabilities breakdown
- Pulls from all connected account types
- Manual asset entry (real estate, vehicles, etc.)

**Translation for Shilling:** In double-entry, net worth = equity = assets − liabilities. We compute this naturally. The line chart over time is the key deliverable (PROJ-00022).

---

## What People Love (Review Synthesis)

1. **"The UI is top notch"** — consistently the #1 praise point across reviews
2. **Light background + clear font + cool green/blue accents** — specific visual praise
3. **Nothing feels overwhelming** despite feature breadth
4. **Easy categorization** — automatic with easy manual override
5. **One-screen financial overview** — seeing everything in one place
6. **Clean report visualizations** — described as "super clean and easy to read"
7. **Active community** — responsive Reddit presence, fast customer support
8. **Partner mode** — unique differentiator for couples

### What People Criticize

1. **Budgeting is not the strongest feature** — Reddit users note Monarch/Rocket Money are better pure budgeters
2. **Price** — $13/mo is steep vs free alternatives
3. **Jack of all trades** — tries to do everything, some features shallow

---

## Copilot Money — Supplementary Reference

Copilot Money is another relevant design reference, especially for macOS:

- **Native Swift app** (UIKit with SwiftUI for newer features like Cash Flow)
- **Apple Design Award finalist** — validates the native-first approach
- **Uses Swift Charts** for all data visualization
- **Color system:** red (expenses), green (income), blue (neutral) on white backgrounds
- **"Crystal-clear interface design"** — similar minimalist philosophy to Origin
- **Local data storage** — fast, responsive interactions
- **macOS app = iOS app + Mac-specific UI components** — universal binary

Key quote from Copilot's team: "The app is fully native; we've just managed to take core UIKit components and mold them to what we want them to look like."

**Translation for Shilling:** We're already native SwiftUI — good. We should adopt Swift Charts for all visualizations rather than building custom. Copilot validates that a small team can build a polished, Apple-quality finance app with native tools.

---

## Sources

- [Origin homepage](https://useorigin.com/)
- [Origin fall 2024 redesign announcement](https://useorigin.com/resources/blog/origin-fall-launch)
- [Origin spending features](https://useorigin.com/products/spending)
- [Origin advanced reports](https://useorigin.com/resources/blog/advanced-reports-custom-budget-spending-trends)
- [Origin new spending features](https://useorigin.com/resources/blog/new-spending-features-make-your-budget-more-customizable)
- [Rob Berger review](https://robberger.com/origin-review/)
- [Origin vs Copilot Money comparison](https://useorigin.com/resources/blog/copilot-money-vs-origin-financial-app-budget-review-comparison)
- [Origin App Store listing](https://apps.apple.com/us/app/origin-ai-budget-and-track/id1637693312)
- [Origin landing page](https://landing.useorigin.com/)
- [Copilot Money — Apple Developer article on Swift Charts](https://developer.apple.com/articles/copilot-money/)
- [The College Investor — Origin review](https://thecollegeinvestor.com/53263/origin-app-review/)
- [MoneySmyLife — Origin review](https://www.moneysmylife.com/origin-financial-review/)

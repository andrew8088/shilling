---
status: ready
created: 2026-03-03
---

# Transaction List: Date & Amount Filters

Add date range and amount range filters to the transaction list.

Depends on: PROJ-00025 (design system) for consistent styling.

## Work

- Add date range filter: "From" and "To" `DatePicker`s (compact style)
- Add amount range filter: "Min" and "Max" `CurrencyField`s
- Integrate into existing filter bar (alongside search and account picker)
- Filter logic: transactions must match ALL active filters (AND)
- "Clear" button resets all filters including new ones
- Consider a disclosure/popover for advanced filters to avoid cluttering the main bar

## Acceptance Criteria

- Date range filters work correctly (inclusive on both ends)
- Amount range filters compare against absolute entry amounts
- Filters compose with existing search text and account filter
- Clear resets everything
- Filter bar doesn't become too wide — use popover or second row if needed

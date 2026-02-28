---
status: ready
created: 2026-02-28
---

# Import UI

macOS app UI for importing CSV files.

## Work
- File picker to select CSV
- Preview parsed rows in a table
- Column mapping controls (dropdowns to assign date/payee/amount/memo)
- Target account and contra account pickers
- Import button with progress and summary (X imported, Y skipped as duplicates)
- Also expose import via CLI: `shilling import csv <file> --account <name> --date-col <n> --amount-col <n> --payee-col <n>`

## Acceptance Criteria
- User can import a CSV file through the macOS app UI
- CLI import works for scripted/automated imports
- Duplicate handling is communicated clearly

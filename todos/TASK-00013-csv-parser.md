---
status: complete
created: 2026-02-28
completed: 2026-02-28
---

# CSV Parser

Parse CSV files and extract transaction data.

## Work
- Parse CSV with configurable delimiter (comma, semicolon, tab)
- Auto-detect header row
- Handle common date formats
- Handle amount as single column (signed) or separate debit/credit columns
- Return parsed rows as structured data for mapping

## Acceptance Criteria
- Parses standard bank CSV exports
- Handles various date formats
- Handles signed amounts and split debit/credit columns
- Error handling for malformed CSVs
- Unit tests with sample CSV data

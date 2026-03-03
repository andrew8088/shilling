---
status: complete
created: 2026-02-28
completed: 2026-03-02
---

# Import Mapping & Execution

Map parsed CSV rows to transactions and import them.

## Work
- Column mapping: user specifies which CSV column maps to date, payee, amount, memo
- Target account selection: which account do the transactions belong to (e.g., "Chequing")
- Default contra account: where does the other side of each entry go (e.g., "Uncategorized Expense")
- Duplicate detection: skip rows where date + amount + payee match existing transactions
- Create ImportRecord to track the import
- Link created transactions to the ImportRecord

## Acceptance Criteria
- Mapping produces valid balanced transactions
- Duplicates are detected and skipped
- ImportRecord is created with correct row count
- Full round-trip test: CSV → parse → map → import → query

# Legacy Postgres Migration SQLite Format

## Purpose

Provide a deterministic, auditable export from legacy Postgres into a migration SQLite file that is safe to import into Shilling without writing directly into SwiftData-managed tables.

Output includes:
- `raw_*` source-fidelity tables for traceability
- `target_*` target-shaped tables for downstream importer consumption
- source-to-target mapping tables
- warning diagnostics for ambiguous or lossy transforms

## Export Command

```bash
python3 scripts/export-legacy-postgres-to-migration-sqlite.py \
  --source-db <source-db> \
  --output /tmp/legacy-migration.sqlite \
  --overwrite
```

Optional:
- `--family-id <uuid>` when the source DB has multiple families.
- `--psql-bin <path>` to override the `psql` executable.

## Table Groups

### Raw source snapshot

- `raw_accounts`
- `raw_categories`
- `raw_transactions`
- `raw_transfers`
- `raw_rejected_transfers`
- `raw_budgets`
- `raw_budget_categories`
- `raw_imports`
- `raw_import_rows`

### Target-shaped records

- `target_accounts`
- `target_import_records`
- `target_transactions`
- `target_entries`
- `target_budgets`

### Traceability and diagnostics

- `map_source_account_to_target_account`
- `map_source_category_to_target_account`
- `map_source_transaction_to_target_transaction`
- `map_source_import_to_target_import_record`
- `warnings`
- `metadata`

## Transformation Rules

### Accounts

- Legacy `accounts` map directly to `target_accounts` with same UUID.
- Legacy `categories` become synthetic accounts:
  - `classification=expense` -> account type `expense`
  - `classification=income` -> account type `income`
- Fallback system account is created:
  - `Legacy Import Suspense` (`account_type=equity`)
  - used when no category mapping exists.

### Transactions and entries

- Each output `target_transactions` row has exactly two entries in `target_entries`.
- Source sign convention is mapped as:
  - `amount > 0` -> primary entry `credit`
  - `amount < 0` -> primary entry `debit`
  - contra entry is always the opposite type.

This sign mapping is intentional and data-driven from this dataset (asset and liability rows both follow outflow-positive / inflow-negative behavior in practice).

### Transfer pairing

Pairs from `raw_transfers` are collapsed into one `target_transactions` row when:

- status is `confirmed`, or
- status is `pending` and all conditions hold:
  - both source transactions have `kind='funds_movement'`
  - both have `category_id IS NULL`
  - amounts are exact opposites
  - date gap is <= 3 days

Pairs in `raw_rejected_transfers` are never collapsed.

### Budgets

- `raw_budget_categories` become `target_budgets`.
- Only expense categories are exported as budgets.
- `year`/`month` are derived from `raw_budgets.start_date`.

### Imports

- Each legacy import maps to one `target_import_records` row.
- `file_name` is synthetic (`legacy-import-<id>.csv`).
- `row_count` comes from counted `raw_import_rows`.

## Diagnostics

All non-fatal issues are captured in `warnings`:

- `transfer_rejected_override`
- `conflicting_import_ids_for_paired_transfer`
- `transaction_missing_category_mapping`
- other data-quality or mapping fallbacks

If hard invariants fail (entry count or balance checks), export exits non-zero and does not keep an output DB.

## Quick Validation Queries

```bash
sqlite3 /tmp/legacy-migration.sqlite \
  "select source_mode, count(*) from target_transactions group by source_mode;"

sqlite3 /tmp/legacy-migration.sqlite \
  "select code, count(*) from warnings group by code order by count(*) desc;"

sqlite3 /tmp/legacy-migration.sqlite \
  "select count(*) as bad
    from (
      select transaction_id,
             sum(case when entry_type='debit' then cast(amount as real) else 0 end) as d,
             sum(case when entry_type='credit' then cast(amount as real) else 0 end) as c
      from target_entries
      group by transaction_id
    ) t
    where abs(d - c) > 0.0001;"
```

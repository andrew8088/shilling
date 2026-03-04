# Legacy Postgres Import Mapping — Handoff (2026-03-04)

## Objective
Map legacy personal-finance data in `psql maybe_2026_03_03` to Shilling's current data model and identify capability gaps required for a high-fidelity import.

## Current Status
- Deep schema exploration is mostly complete.
- Data-model mapping is partially reasoned but not yet written as the final research doc.
- Gap-to-task backlog has not been fully authored yet.

## Access / Environment
- Database: `maybe_2026_03_03`
- Connection command: `psql maybe_2026_03_03`
- Workspace root: `/Users/andrew/code/shilling`

## Key Findings So Far

### 1) Source schema shape (finance-relevant)

High-value table row counts:

| Table | Rows |
|---|---:|
| `balances` | 17,409 |
| `import_rows` | 12,633 |
| `entries` | 8,496 |
| `transactions` | 8,408 |
| `data_enrichments` | 3,057 |
| `transfers` | 752 |
| `budget_categories` | 106 |
| `valuations` | 88 |
| `imports` | 76 |
| `merchants` | 22 |
| `categories` | 17 |
| `rule_actions` | 14 |
| `rule_conditions` | 14 |
| `accounts` | 12 |
| `rules` | 9 |
| `tags` | 9 |
| `budgets` | 7 |
| `rejected_transfers` | 3 |
| `import_mappings` | 3 |

`holdings`, `securities`, `security_prices`, and `trades` are present but currently empty in this dataset.

### 2) Canonical financial data is not double-entry in source
- `transactions` are metadata wrappers; each transaction has exactly one `entries` row.
- Double-sided money movement is represented by `transfers` pairs (two separate transactions with opposite signed amounts), not by two entries in one transaction.
- `entries.entryable_type` is polymorphic:
  - `Transaction`: 8,408
  - `Valuation`: 88

### 3) Sign semantics are account-classification dependent
- Asset accounts: positive usually outflow/decrease; negative usually inflow/increase.
- Liability accounts: positive usually increase liability; negative usually decrease liability.
- This aligns with `balances.flows_factor` (`1` for assets, `-1` for liabilities).

### 4) Transfer layer has confidence/state semantics not present in Shilling
- `transfers`: 752 total
  - `pending`: 673
  - `confirmed`: 79
- `rejected_transfers`: 3 pairs
- 1 pair exists in both `transfers` and `rejected_transfers` (inconsistency).

### 5) Category / merchant / tagging / rule metadata is rich
- `transactions` link to:
  - categories: 3,738 tx
  - merchants: 2,146 tx
- `taggings`: 149 rows across 148 unique transactions.
- Rules:
  - 9 `rules`
  - 14 `rule_conditions` (includes nested/compound via `parent_id`)
  - 14 `rule_actions`
- `data_enrichments` (3,057 rows) stores rule-derived category/merchant metadata.

### 6) Valuation and balance history are first-class in source
- `valuations` + `entries` store absolute account value checkpoints (`reconciliation`, `opening_anchor`).
- `balances` stores daily snapshots and flow decomposition.
- This is much richer than current Shilling models.

### 7) Import staging/provenance data is extensive
- `imports`: 76 (statuses include `complete`, `pending`, `revert_failed`)
- `import_rows`: 12,633 staged rows.
- `entries` linked to imports: 8,297.
- `imports` store parsing/config context (date format, signage convention, amount strategy, column labels, raw file content, etc.).

## Data Quality / Integrity Signals Discovered
- `import_rows.entity_type` is heavily polluted with numeric/date values for many imports (column mis-mapping from legacy workflow).
- One `import_rows.currency` value is malformed (`CAD.00"   Mortgage payment  CAD`).
- One `rule_actions` category reference points to a deleted/missing category UUID.
- `data_enrichments` has one orphan transaction reference.
- Category enrichment references include missing category UUIDs (196 rows).

## Preliminary Mapping Strategy (Not Finalized)

1. Accounts
- Legacy `accounts` (`classification` asset/liability) -> Shilling `Account` (`type` asset/liability).
- Legacy `categories` -> Shilling `Account` (`type` expense/income).

2. Transactions / entries
- Convert each source single-entry transaction into Shilling double-entry using:
  - transfer pair resolution where safe
  - category-derived contra account otherwise
  - fallback suspense/equity account when category missing
- Preserve `kind`, source IDs, and source metadata in notes or metadata fields (pending schema decision).

3. Budgets
- `budget_categories` -> Shilling `Budget` by mapped expense account + (year, month) from budget period.

4. Imports
- Legacy import provenance currently exceeds Shilling `ImportRecord` capacity.
- Need explicit decision: minimal import provenance vs full import-history preservation.

## Likely Shilling Capability Gaps

Gaps that appear real after exploration:
- No native tag model (`tags`/`taggings` cannot be imported semantically).
- No valuation snapshot model (legacy absolute valuations cannot be represented cleanly).
- No daily balance snapshot model (legacy `balances` history would be lost).
- No transfer-link status model (`pending`/`confirmed`/`rejected` semantics are lost).
- No extensible metadata field for source `transaction.kind`, source IDs, and import context.
- Rule model parity likely incomplete for nested condition trees and action import.

## Suggested Next Steps To Continue

1. Finish one blocked query (missing category enrichment IDs distribution):
```sql
with normalized as (
  select enrichable_id, replace(value::text, chr(34), '') as normalized_value
  from data_enrichments
  where enrichable_type='Transaction' and attribute_name='category_id'
)
select normalized_value as missing_category_id, count(*) as n
from normalized
where normalized_value ~ '^[0-9a-fA-F-]{36}$'
  and normalized_value::uuid not in (select id from categories)
group by normalized_value
order by n desc;
```

2. Write final research doc (target path):
- `docs/legacy-postgres-import-mapping-research.md`
- Include:
  - source-to-target field matrix
  - deterministic conversion rules for sign -> debit/credit
  - transfer pairing policy for `pending/confirmed/rejected`
  - explicit loss table (what is lost under current model)

3. Create recommended capability tickets (new backlog) after final mapping:
- Tag model + transaction tagging
- Valuation snapshot model
- Balance snapshot model
- Transfer link/status model
- Source metadata fields for import fidelity
- Nested rule-import support

4. Complete ticket updates:
- Mark `TASK-00086` complete when mapping doc is finalized.
- Run `TASK-00087` by creating recommended capability tasks and sequencing.


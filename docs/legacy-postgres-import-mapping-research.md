# Legacy Postgres Import Mapping Research (2026-03-04)

## Scope
Source: `maybe_2026_03_03` (legacy Postgres finance app)  
Target: current Shilling core models only:
- `Account`
- `Transaction`
- `Entry`
- `Budget`
- `ImportRecord`

This document defines deterministic mapping rules for importing legacy data into the current Shilling schema and enumerates fidelity losses that require follow-up model work.

## Evidence Snapshot
- `transactions`: 8,408 rows
- `entries` (`entryable_type='Transaction'`): 8,408 rows
- `entries` (`entryable_type='Valuation'`): 88 rows
- `transfers`: 752 rows (`confirmed=79`, `pending=673`)
- `rejected_transfers`: 3 rows
- overlap between `transfers` and `rejected_transfers`: 1 pair
- `budget_categories`: 106 rows across 16 categories, all month-aligned budgets
- `imports`: 76 rows (`complete=68`, `pending=2`, `revert_failed=6`)
- `import_rows`: 12,633 rows

Key observed source conventions:
- Every legacy transaction has exactly one `entries` row.
- Amount convention in `entries.amount` is outflow-positive and inflow-negative.
- Transfer pair amounts are exact opposites in all 752 transfer pairs.
- 83/752 transfer pairs have date mismatch across the two sides (max observed gap: 4 days).

## Deterministic Mapping Rules

### 1) Accounts
Legacy `accounts` -> Shilling `Account`
- `accounts.name` -> `Account.name`
- `accounts.classification` mapping:
  - `asset` -> `.asset`
  - `liability` -> `.liability`
- `accounts.status='disabled'` -> `Account.isArchived=true`, else `false`
- `accounts.id` stored in metadata note string (see metadata policy below)

Unsupported account attributes now:
- subtype, currency, locked attributes, accountable polymorphism

### 2) Categories
Legacy `categories` -> Shilling `Account` (synthetic category accounts)
- `categories.classification='expense'` -> `.expense`
- `categories.classification='income'` -> `.income`
- Name policy: `Category: <legacy category name>`
- Keep a lookup map `{legacy_category_id -> category_account_id}`

Unsupported category attributes now:
- color, icon, parent hierarchy metadata

### 3) Transactions and Entries

#### 3.1 Entry type conversion (sign -> debit/credit)
Use legacy outflow-positive convention:

| Legacy account classification | `amount > 0` | `amount < 0` |
|---|---|---|
| `asset` | primary entry `.credit` | primary entry `.debit` |
| `liability` | primary entry `.debit` | primary entry `.credit` |

Implementation rule:
- `absAmount = abs(entries.amount)`
- Primary entry uses table above.
- Contra entry uses opposite entry type.

#### 3.2 Independent (non-paired) transaction mapping
For each legacy transaction `t` with entry `e` not consumed by transfer pairing:
- `Transaction.date = e.date`
- `Transaction.payee = trimmed(e.name)`; fallback `"Legacy Transaction"`
- `Transaction.notes` appends legacy metadata (IDs/kind/merchant/tag info) as plain text
- Primary account = mapped `accounts[e.account_id]`
- Primary entry = `(account=primary account, amount=abs(e.amount), type=converted primary type)`
- Contra account selection:
  - if `t.category_id` maps to a category account: use that
  - else: use synthetic equity account `Legacy Import Suspense`
- Contra entry type = opposite of primary entry type

#### 3.3 Transfer pairing policy (`pending` / `confirmed` / `rejected`)
Build two sets of undirected transaction-ID pairs:
- `rejected_pairs` from `rejected_transfers`
- `transfer_rows` from `transfers`

For each `transfers` row:
1. If pair exists in `rejected_pairs`: **do not pair** (import as two independent transactions).
2. Else if `status='confirmed'`: **pair** into one Shilling transfer transaction.
3. Else if `status='pending'`: pair only when all are true:
   - both legacy transactions have `kind='funds_movement'`
   - both have `category_id IS NULL`
   - amounts are exact opposites
   - absolute date gap <= 3 days
   Otherwise keep independent.

Paired transfer construction:
- Date: later of the two source dates (`max(inflow_date, outflow_date)`)
- Payee: non-empty outflow `entries.name`, else inflow name, else `"Transfer"`
- Two entries only (no category contra):
  - outflow-side account gets decrease entry type for its account normal balance
  - inflow-side account gets increase entry type for its account normal balance
- Append pair metadata (`status`, both source tx IDs) into notes

Rationale:
- `confirmed` rows are explicit matches.
- `pending` rows contain likely matches but also obvious false-positive candidates; conservative heuristics avoid importing uncertain links as hard transfers.
- `rejected_transfers` is treated as authoritative override.

### 4) Budgets
Legacy `budget_categories` + `budgets` -> Shilling `Budget`
- For each `budget_categories` row:
  - Resolve legacy category -> synthetic expense account
  - Use period from joined `budgets.start_date`
  - `Budget.year = year(start_date)`
  - `Budget.month = month(start_date)`
  - `Budget.amount = budgeted_spending`
- Only expense categories are imported as budgets.

### 5) Import Provenance
Legacy `imports`/`entries.import_id` -> Shilling `ImportRecord`
- One `ImportRecord` per legacy `imports.id`
- `ImportRecord.fileName = "legacy-import-<import_id>.csv"` (synthetic)
- `ImportRecord.rowCount = count(import_rows where import_id=<id>)`
- Link imported transactions through `entries.import_id`
- `importedAt` cannot be backfilled in current model (uses now on create)

## Source -> Target Field Matrix

| Legacy source | Target mapping | Notes |
|---|---|---|
| `accounts.id,name,classification,status` | `Account` | deterministic direct map |
| `categories.id,name,classification` | synthetic `Account` of type income/expense | category becomes contra account |
| `transactions.id,kind,category_id,merchant_id` + `entries.*` | `Transaction` + 2-entry balanced posting | one source row -> one balanced journal entry |
| `transfers(status,inflow_transaction_id,outflow_transaction_id)` | paired `Transaction` where policy allows | status itself not first-class in model |
| `rejected_transfers` | pairing exclusion set | authoritative override |
| `budgets` + `budget_categories` | `Budget` | month-aligned in this dataset |
| `imports` + `entries.import_id` + `import_rows` | `ImportRecord` + tx links | heavy provenance loss |
| `merchants` + merchant refs | note text only | no merchant model in target |
| `tags` + `taggings` | dropped (or note text only) | no tag model in target |
| `rules`, `rule_conditions`, `rule_actions`, `data_enrichments` | dropped as behavior; some effect already baked into tx category/merchant fields | nested rule tree not representable |
| `valuations` + valuation entries | dropped from current ledger import | requires snapshot/revaluation model |
| `balances` history | dropped | requires balance snapshot model |

## Explicit Loss Table (Current Model)

| Legacy semantic | Current handling | Fidelity impact |
|---|---|---|
| Transfer lifecycle (`pending`/`confirmed`/`rejected`) | only partial inference via import-time pairing, no persisted link/status | cannot audit or revise transfer decisions later |
| Tags and taggings | not modeled | tag search/reporting lost |
| Merchant entity | not modeled (notes only) | merchant-level analytics lost |
| Rule trees and actions | not modeled | cannot preserve automation behavior |
| Data enrichment provenance | not modeled | cannot replay/inspect enrichment origin |
| Valuation checkpoints | not modeled | historical valuation timeline lost |
| Daily balance history/flows | not modeled | historical net-worth reconstruction lost |
| Import staging config/raw rows | not modeled | cannot replay/revert/audit imports with source fidelity |
| Source IDs/typed metadata | notes string only | weak traceability and brittle round-tripping |

## Data Quality Notes Affecting Import
- One `category_id` value in enrichment references a deleted category (`196` rows).
- One `rule_actions` category reference points to missing category.
- One orphan `data_enrichments` transaction reference.
- One malformed `import_rows.currency` value.
- One transfer pair appears both confirmed and rejected; rejected should win.

## Recommended Backlog
Active roadmap (user-facing first):
- `PROJ-00096-user-facing-import-and-trust-workflows.md`

Parked fidelity/parity backlog (deferred pending explicit demand):
- `PROJ-00088-legacy-postgres-import-fidelity-gaps.md`
- `TASK-00091-add-tag-model-and-transaction-tagging.md`
- `TASK-00092-add-valuation-snapshot-model-and-import.md`
- `TASK-00093-add-daily-balance-snapshot-model-and-import.md`
- `TASK-00094-add-import-provenance-staging-models.md`
- `TASK-00095-extend-rule-model-for-legacy-nested-rule-parity.md`

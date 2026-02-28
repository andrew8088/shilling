---
status: ready
created: 2026-02-28
---

# Implement SwiftData Domain Models

Define all SwiftData `@Model` classes and supporting types in ShillingCore.

## Models
- `Account` — with AccountType enum (asset, liability, equity, income, expense), parent/child hierarchy, archive flag
- `Transaction` — date, payee, notes, relationship to entries
- `Entry` — amount (Decimal), EntryType enum (debit/credit), memo, relationships to transaction and account
- `Budget` — year, month, target amount, relationship to expense account
- `ImportRecord` — fileName, importedAt, rowCount

## Supporting Types
- `AccountType` enum (raw value String for SwiftData compatibility)
- `EntryType` enum (debit, credit)

## Acceptance Criteria
- All models compile and can be registered in a ModelContainer
- Unit tests verify model creation, relationships, and enum behavior
- In-memory ModelContainer used for tests

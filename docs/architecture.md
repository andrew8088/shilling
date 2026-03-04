# Architecture

## Project Structure

```
shilling/
├── ShillingCore/                    # Swift Package (library)
│   ├── Package.swift
│   ├── Sources/ShillingCore/
│   │   ├── Models/                  # SwiftData @Model classes
│   │   ├── Services/               # Business logic
│   │   └── Import/                 # CSV import
│   └── Tests/ShillingCoreTests/
│
├── Shilling/                        # macOS SwiftUI app (Xcode project)
│   ├── Shilling.xcodeproj
│   └── Shilling/
│       ├── ShillingApp.swift
│       ├── Views/
│       └── ViewModels/
│
├── ShillingCLI/                     # CLI executable (in ShillingCore package)
│   └── main.swift
│
├── docs/
└── todos/
```

## Layer Responsibilities

### ShillingCore (Swift Package)
The shared library. No UI dependencies. Contains:

- **Models**: SwiftData `@Model` classes defining the schema
- **Services**: Business logic (transaction validation, budget calculations, balance computations)
- **Import**: CSV parsing and transaction mapping

Both the macOS app and CLI depend on this package. All domain logic lives here.

### Shilling (macOS App)
SwiftUI app. Thin layer over ShillingCore:

- Creates and owns the `ModelContainer`
- Views bind to SwiftData queries via `@Query`
- ViewModels coordinate service calls where needed
- No business logic — delegates everything to ShillingCore services

### ShillingCLI
Command-line interface using swift-argument-parser:

- Creates its own `ModelContainer` pointing to the same SQLite file
- Subcommands for common operations (list accounts, add transactions, import CSV, reports)
- JSON output mode for scripting

## Domain Model (Double-Entry Bookkeeping)

### Account
- `id: UUID`
- `name: String`
- `type: AccountType` — asset, liability, equity, income, expense
- `parent: Account?` — for hierarchy (e.g., Expenses > Food > Groceries)
- `children: [Account]`
- `isArchived: Bool`
- `notes: String?`
- `createdAt: Date`
- compatibility: persisted `accountType` raw strings are decoded leniently (`trim + lowercase`); invalid values fall back to `.asset` instead of crashing

### Transaction (Journal Entry)
- `id: UUID`
- `date: Date`
- `payee: String`
- `notes: String?`
- `entries: [Entry]` — must have at least 2 entries; sum of debits must equal sum of credits
- `createdAt: Date`

### Entry (Split/Line)
- `id: UUID`
- `transaction: Transaction`
- `account: Account`
- `amount: Decimal` — always positive
- `type: EntryType` — `.debit` or `.credit`
- `memo: String?`
- compatibility: persisted `entryType` raw strings are decoded leniently (`trim + lowercase`); invalid values fall back to `.debit` instead of crashing

### Budget
- `id: UUID`
- `account: Account` — must be an expense account
- `year: Int`
- `month: Int`
- `amount: Decimal` — target spending for the period

### ImportRecord
- `id: UUID`
- `fileName: String`
- `importedAt: Date`
- `rowCount: Int`

Transactions from imports get linked back to the ImportRecord to prevent duplicate imports.

## Key Patterns

### Opening Balances
A seed account of type `.equity` named "Opening Balances" is created automatically.
To set an opening balance for any account, create a transaction:
- Debit: the account (if asset) / Credit: Opening Balances
- Or the reverse for liabilities

### Mortgage Payments
A mortgage is a liability account. A payment transaction has three entries:
- **Debit**: Mortgage account (principal portion — reduces liability)
- **Debit**: Interest Expense account (interest portion)
- **Credit**: Bank/chequing account (total payment amount)

### Transaction Validation
Every transaction must satisfy:
- At least 2 entries
- Sum of all debit amounts == sum of all credit amounts
- No zero-amount entries

### Account Balances
Balances are computed, not stored. For a given account:
- Assets & Expenses: sum of debits − sum of credits (debit-normal)
- Liabilities, Equity & Income: sum of credits − sum of debits (credit-normal)

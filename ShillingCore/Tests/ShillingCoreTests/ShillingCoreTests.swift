import Foundation
import Testing
import SwiftData
@testable import ShillingCore

// MARK: - AccountType

@Suite("AccountType")
struct AccountTypeTests {
    @Test func assetIsDebitNormal() {
        #expect(AccountType.asset.isDebitNormal == true)
    }

    @Test func expenseIsDebitNormal() {
        #expect(AccountType.expense.isDebitNormal == true)
    }

    @Test func liabilityIsNotDebitNormal() {
        #expect(AccountType.liability.isDebitNormal == false)
    }

    @Test func equityIsNotDebitNormal() {
        #expect(AccountType.equity.isDebitNormal == false)
    }

    @Test func incomeIsNotDebitNormal() {
        #expect(AccountType.income.isDebitNormal == false)
    }

    @Test func allCasesExist() {
        let cases = AccountType.allCases
        #expect(cases.count == 5)
        #expect(cases.contains(.asset))
        #expect(cases.contains(.liability))
        #expect(cases.contains(.equity))
        #expect(cases.contains(.income))
        #expect(cases.contains(.expense))
    }

    @Test func rawValuesMatchCaseName() {
        #expect(AccountType.asset.rawValue == "asset")
        #expect(AccountType.liability.rawValue == "liability")
        #expect(AccountType.equity.rawValue == "equity")
        #expect(AccountType.income.rawValue == "income")
        #expect(AccountType.expense.rawValue == "expense")
    }

    @Test func initFromRawValue() {
        #expect(AccountType(rawValue: "asset") == .asset)
        #expect(AccountType(rawValue: "liability") == .liability)
        #expect(AccountType(rawValue: "equity") == .equity)
        #expect(AccountType(rawValue: "income") == .income)
        #expect(AccountType(rawValue: "expense") == .expense)
        #expect(AccountType(rawValue: "unknown") == nil)
    }
}

// MARK: - EntryType

@Suite("EntryType")
struct EntryTypeTests {
    @Test func allCasesExist() {
        let cases = EntryType.allCases
        #expect(cases.count == 2)
        #expect(cases.contains(.debit))
        #expect(cases.contains(.credit))
    }

    @Test func rawValuesMatchCaseName() {
        #expect(EntryType.debit.rawValue == "debit")
        #expect(EntryType.credit.rawValue == "credit")
    }

    @Test func initFromRawValue() {
        #expect(EntryType(rawValue: "debit") == .debit)
        #expect(EntryType(rawValue: "credit") == .credit)
        #expect(EntryType(rawValue: "unknown") == nil)
    }
}

// MARK: - Account

@Suite("Account")
struct AccountTests {
    @Test @MainActor func createAccountWithDefaults() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Checking", type: .asset)
        context.insert(account)
        try context.save()

        #expect(account.name == "Checking")
        #expect(account.type == .asset)
        #expect(account.accountType == "asset")
        #expect(account.isArchived == false)
        #expect(account.notes == nil)
        #expect(account.parent == nil)
        #expect(account.children.isEmpty)
        #expect(account.entries.isEmpty)
        #expect(account.budgets.isEmpty)
    }

    @Test @MainActor func createAccountWithAllFields() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(
            name: "Savings",
            type: .asset,
            isArchived: true,
            notes: "Emergency fund"
        )
        context.insert(account)
        try context.save()

        #expect(account.name == "Savings")
        #expect(account.type == .asset)
        #expect(account.isArchived == true)
        #expect(account.notes == "Emergency fund")
    }

    @Test @MainActor func accountIdIsUnique() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let a1 = Account(name: "Checking", type: .asset)
        let a2 = Account(name: "Savings", type: .asset)
        context.insert(a1)
        context.insert(a2)
        try context.save()

        #expect(a1.id != a2.id)
    }

    @Test @MainActor func accountTypeComputedPropertyRoundtrips() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Rent", type: .expense)
        context.insert(account)
        try context.save()

        // Verify initial type
        #expect(account.type == .expense)
        #expect(account.accountType == "expense")

        // Mutate via computed property
        account.type = .liability
        try context.save()

        #expect(account.type == .liability)
        #expect(account.accountType == "liability")
    }

    @Test @MainActor func accountTypeFallsBackForInvalidPersistedRawValue() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Malformed", type: .asset)
        context.insert(account)
        try context.save()

        account.accountType = "not-a-real-type"
        try context.save()

        #expect(account.type == .asset)
        #expect(account.accountType == "not-a-real-type")
    }

    @Test @MainActor func accountTypeDecodesCaseAndWhitespaceVariations() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Normalized", type: .asset)
        context.insert(account)
        try context.save()

        account.accountType = "  LiABility  "
        try context.save()

        #expect(account.type == .liability)
    }

    @Test @MainActor func parentChildRelationship() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let parent = Account(name: "Assets", type: .asset)
        let child = Account(name: "Checking", type: .asset, parent: parent)
        context.insert(parent)
        context.insert(child)
        try context.save()

        #expect(child.parent?.name == "Assets")
        #expect(parent.children.count == 1)
        #expect(parent.children.first?.name == "Checking")
    }

    @Test @MainActor func multipleChildrenRelationship() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let parent = Account(name: "Assets", type: .asset)
        let child1 = Account(name: "Checking", type: .asset, parent: parent)
        let child2 = Account(name: "Savings", type: .asset, parent: parent)
        context.insert(parent)
        context.insert(child1)
        context.insert(child2)
        try context.save()

        let childNames = parent.children.map(\.name).sorted()
        #expect(childNames == ["Checking", "Savings"])
        #expect(child1.parent?.id == parent.id)
        #expect(child2.parent?.id == parent.id)
    }

    @Test @MainActor func accountCreatedAtIsSet() throws {
        let before = Date()
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Checking", type: .asset)
        context.insert(account)
        try context.save()

        let after = Date()
        #expect(account.createdAt >= before)
        #expect(account.createdAt <= after)
    }

    @Test @MainActor func allAccountTypesCanBeCreated() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        for accountType in AccountType.allCases {
            let account = Account(name: accountType.rawValue, type: accountType)
            context.insert(account)
        }
        try context.save()

        let descriptor = FetchDescriptor<Account>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == AccountType.allCases.count)
    }
}

// MARK: - Transaction

@Suite("Transaction")
struct TransactionTests {
    @Test @MainActor func createTransactionWithDefaults() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let date = Date()
        let transaction = Transaction(date: date, payee: "Whole Foods")
        context.insert(transaction)
        try context.save()

        #expect(transaction.payee == "Whole Foods")
        #expect(transaction.notes == nil)
        #expect(transaction.importRecord == nil)
        #expect(transaction.entries.isEmpty)
    }

    @Test @MainActor func createTransactionWithNotes() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let transaction = Transaction(date: Date(), payee: "Amazon", notes: "Office supplies")
        context.insert(transaction)
        try context.save()

        #expect(transaction.payee == "Amazon")
        #expect(transaction.notes == "Office supplies")
    }

    @Test @MainActor func transactionIdIsUnique() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let t1 = Transaction(date: Date(), payee: "Payee A")
        let t2 = Transaction(date: Date(), payee: "Payee B")
        context.insert(t1)
        context.insert(t2)
        try context.save()

        #expect(t1.id != t2.id)
    }

    @Test @MainActor func transactionCreatedAtIsSet() throws {
        let before = Date()
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let transaction = Transaction(date: Date(), payee: "Test Payee")
        context.insert(transaction)
        try context.save()

        let after = Date()
        #expect(transaction.createdAt >= before)
        #expect(transaction.createdAt <= after)
    }

    @Test @MainActor func transactionDateIsStoredCorrectly() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let specificDate = Date(timeIntervalSince1970: 1_700_000_000)
        let transaction = Transaction(date: specificDate, payee: "Payee")
        context.insert(transaction)
        try context.save()

        #expect(transaction.date == specificDate)
    }
}

// MARK: - Entry

@Suite("Entry")
struct EntryTests {
    @Test @MainActor func createDebitEntry() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Checking", type: .asset)
        context.insert(account)

        let entry = Entry(account: account, amount: 100.00, type: .debit)
        context.insert(entry)
        try context.save()

        #expect(entry.amount == 100.00)
        #expect(entry.type == .debit)
        #expect(entry.entryType == "debit")
        #expect(entry.memo == nil)
        #expect(entry.account?.name == "Checking")
    }

    @Test @MainActor func createCreditEntry() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Revenue", type: .income)
        context.insert(account)

        let entry = Entry(account: account, amount: 250.50, type: .credit)
        context.insert(entry)
        try context.save()

        #expect(entry.amount == 250.50)
        #expect(entry.type == .credit)
        #expect(entry.entryType == "credit")
    }

    @Test @MainActor func entryTypeComputedPropertyRoundtrips() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Checking", type: .asset)
        context.insert(account)

        let entry = Entry(account: account, amount: 50.00, type: .debit)
        context.insert(entry)
        try context.save()

        #expect(entry.type == .debit)
        #expect(entry.entryType == "debit")

        entry.type = .credit
        try context.save()

        #expect(entry.type == .credit)
        #expect(entry.entryType == "credit")
    }

    @Test @MainActor func entryTypeFallsBackForInvalidPersistedRawValue() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Checking", type: .asset)
        context.insert(account)

        let entry = Entry(account: account, amount: 50.00, type: .credit)
        context.insert(entry)
        try context.save()

        entry.entryType = "unexpected"
        try context.save()

        #expect(entry.type == .debit)
        #expect(entry.entryType == "unexpected")
    }

    @Test @MainActor func entryTypeDecodesCaseAndWhitespaceVariations() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Checking", type: .asset)
        context.insert(account)

        let entry = Entry(account: account, amount: 20.00, type: .debit)
        context.insert(entry)
        try context.save()

        entry.entryType = "  CREDIT  "
        try context.save()

        #expect(entry.type == .credit)
    }

    @Test @MainActor func createEntryWithMemo() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Checking", type: .asset)
        context.insert(account)

        let entry = Entry(account: account, amount: 75.00, type: .debit, memo: "Lunch")
        context.insert(entry)
        try context.save()

        #expect(entry.memo == "Lunch")
    }

    @Test @MainActor func entryIdIsUnique() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Checking", type: .asset)
        context.insert(account)

        let e1 = Entry(account: account, amount: 10.00, type: .debit)
        let e2 = Entry(account: account, amount: 20.00, type: .credit)
        context.insert(e1)
        context.insert(e2)
        try context.save()

        #expect(e1.id != e2.id)
    }

    @Test @MainActor func entryTransactionIsNilByDefault() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Checking", type: .asset)
        context.insert(account)

        let entry = Entry(account: account, amount: 10.00, type: .debit)
        context.insert(entry)
        try context.save()

        #expect(entry.transaction == nil)
    }
}

// MARK: - Budget

@Suite("Budget")
struct BudgetTests {
    @Test @MainActor func createBudget() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Groceries", type: .expense)
        context.insert(account)

        let budget = Budget(account: account, year: 2026, month: 3, amount: 500.00)
        context.insert(budget)
        try context.save()

        #expect(budget.year == 2026)
        #expect(budget.month == 3)
        #expect(budget.amount == 500.00)
        #expect(budget.account?.name == "Groceries")
    }

    @Test @MainActor func budgetIdIsUnique() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Groceries", type: .expense)
        context.insert(account)

        let b1 = Budget(account: account, year: 2026, month: 1, amount: 400.00)
        let b2 = Budget(account: account, year: 2026, month: 2, amount: 450.00)
        context.insert(b1)
        context.insert(b2)
        try context.save()

        #expect(b1.id != b2.id)
    }

    @Test @MainActor func budgetAmountStoredCorrectly() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Utilities", type: .expense)
        context.insert(account)

        let amount: Decimal = 123.45
        let budget = Budget(account: account, year: 2026, month: 6, amount: amount)
        context.insert(budget)
        try context.save()

        #expect(budget.amount == amount)
    }

    @Test @MainActor func accountBudgetsRelationship() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Dining", type: .expense)
        context.insert(account)

        let b1 = Budget(account: account, year: 2026, month: 1, amount: 200.00)
        let b2 = Budget(account: account, year: 2026, month: 2, amount: 220.00)
        context.insert(b1)
        context.insert(b2)
        try context.save()

        #expect(account.budgets.count == 2)
    }
}

// MARK: - ImportRecord

@Suite("ImportRecord")
struct ImportRecordTests {
    @Test @MainActor func createImportRecord() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let record = ImportRecord(fileName: "transactions_2026.csv", rowCount: 42)
        context.insert(record)
        try context.save()

        #expect(record.fileName == "transactions_2026.csv")
        #expect(record.rowCount == 42)
        #expect(record.transactions.isEmpty)
    }

    @Test @MainActor func importRecordIdIsUnique() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let r1 = ImportRecord(fileName: "file1.csv", rowCount: 10)
        let r2 = ImportRecord(fileName: "file2.csv", rowCount: 20)
        context.insert(r1)
        context.insert(r2)
        try context.save()

        #expect(r1.id != r2.id)
    }

    @Test @MainActor func importRecordImportedAtIsSet() throws {
        let before = Date()
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let record = ImportRecord(fileName: "data.csv", rowCount: 5)
        context.insert(record)
        try context.save()

        let after = Date()
        #expect(record.importedAt >= before)
        #expect(record.importedAt <= after)
    }

    @Test @MainActor func importRecordWithZeroRows() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let record = ImportRecord(fileName: "empty.csv", rowCount: 0)
        context.insert(record)
        try context.save()

        #expect(record.rowCount == 0)
    }
}

// MARK: - ModelContainer

@Suite("ModelContainer")
struct ModelContainerTests {
    @Test @MainActor func makeInMemorySucceeds() throws {
        // Simply verifying the call doesn't throw
        _ = try ModelContainerSetup.makeInMemory()
    }

    @Test @MainActor func makeInMemoryCanInsertAndFetchAccount() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Checking", type: .asset)
        context.insert(account)
        try context.save()

        let descriptor = FetchDescriptor<Account>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Checking")
    }

    @Test @MainActor func makeInMemoryCanInsertAndFetchTransaction() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let transaction = Transaction(date: Date(), payee: "Test Payee")
        context.insert(transaction)
        try context.save()

        let descriptor = FetchDescriptor<Transaction>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.payee == "Test Payee")
    }

    @Test @MainActor func makeInMemoryCanInsertAndFetchEntry() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Checking", type: .asset)
        context.insert(account)

        let entry = Entry(account: account, amount: 99.99, type: .debit)
        context.insert(entry)
        try context.save()

        let descriptor = FetchDescriptor<Entry>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.amount == 99.99)
    }

    @Test @MainActor func makeInMemoryCanInsertAndFetchBudget() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Groceries", type: .expense)
        context.insert(account)

        let budget = Budget(account: account, year: 2026, month: 1, amount: 300.00)
        context.insert(budget)
        try context.save()

        let descriptor = FetchDescriptor<Budget>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.amount == 300.00)
    }

    @Test @MainActor func makeInMemoryCanInsertAndFetchImportRecord() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let record = ImportRecord(fileName: "import.csv", rowCount: 15)
        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<ImportRecord>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.fileName == "import.csv")
    }

    @Test @MainActor func separateInMemoryContainersAreIsolated() throws {
        let container1 = try ModelContainerSetup.makeInMemory()
        let context1 = ModelContext(container1)
        let account = Account(name: "Checking", type: .asset)
        context1.insert(account)
        try context1.save()

        let container2 = try ModelContainerSetup.makeInMemory()
        let context2 = ModelContext(container2)
        let descriptor = FetchDescriptor<Account>()
        let fetched = try context2.fetch(descriptor)
        #expect(fetched.isEmpty)
    }
}

// MARK: - Relationships

@Suite("Relationships")
struct RelationshipTests {
    @Test @MainActor func transactionEntryRelationshipPersists() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let checkingAccount = Account(name: "Checking", type: .asset)
        let groceriesAccount = Account(name: "Groceries", type: .expense)
        context.insert(checkingAccount)
        context.insert(groceriesAccount)

        let transaction = Transaction(date: Date(), payee: "Whole Foods")
        context.insert(transaction)

        let debitEntry = Entry(account: groceriesAccount, amount: 85.00, type: .debit)
        let creditEntry = Entry(account: checkingAccount, amount: 85.00, type: .credit)
        context.insert(debitEntry)
        context.insert(creditEntry)

        transaction.entries.append(debitEntry)
        transaction.entries.append(creditEntry)
        debitEntry.transaction = transaction
        creditEntry.transaction = transaction

        try context.save()

        #expect(transaction.entries.count == 2)
        #expect(debitEntry.transaction?.payee == "Whole Foods")
        #expect(creditEntry.transaction?.payee == "Whole Foods")
        #expect(debitEntry.account?.name == "Groceries")
        #expect(creditEntry.account?.name == "Checking")
    }

    @Test @MainActor func accountEntriesRelationshipPersists() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Checking", type: .asset)
        context.insert(account)

        let t1 = Transaction(date: Date(), payee: "Payee A")
        let t2 = Transaction(date: Date(), payee: "Payee B")
        context.insert(t1)
        context.insert(t2)

        let e1 = Entry(account: account, amount: 100.00, type: .debit)
        let e2 = Entry(account: account, amount: 50.00, type: .credit)
        context.insert(e1)
        context.insert(e2)

        t1.entries.append(e1)
        e1.transaction = t1
        t2.entries.append(e2)
        e2.transaction = t2

        try context.save()

        #expect(account.entries.count == 2)
    }

    @Test @MainActor func importRecordTransactionRelationshipPersists() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let record = ImportRecord(fileName: "bank.csv", rowCount: 2)
        context.insert(record)

        let t1 = Transaction(date: Date(), payee: "Payee A", importRecord: record)
        let t2 = Transaction(date: Date(), payee: "Payee B", importRecord: record)
        context.insert(t1)
        context.insert(t2)

        record.transactions.append(t1)
        record.transactions.append(t2)

        try context.save()

        #expect(record.transactions.count == 2)
        #expect(t1.importRecord?.fileName == "bank.csv")
        #expect(t2.importRecord?.fileName == "bank.csv")
    }

    @Test @MainActor func fullDoubleEntryTransactionPersists() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        // Chart of accounts
        let checking = Account(name: "Checking", type: .asset)
        let rent = Account(name: "Rent", type: .expense)
        context.insert(checking)
        context.insert(rent)

        // A rent payment: debit Rent, credit Checking
        let txDate = Date(timeIntervalSince1970: 1_740_000_000)
        let transaction = Transaction(date: txDate, payee: "Landlord", notes: "March rent")
        context.insert(transaction)

        let debit = Entry(account: rent, amount: 1500.00, type: .debit, memo: "March")
        let credit = Entry(account: checking, amount: 1500.00, type: .credit, memo: "March")
        context.insert(debit)
        context.insert(credit)

        transaction.entries.append(debit)
        transaction.entries.append(credit)
        debit.transaction = transaction
        credit.transaction = transaction

        try context.save()

        // Verify via fetch
        let txDescriptor = FetchDescriptor<Transaction>()
        let txFetched = try context.fetch(txDescriptor)
        #expect(txFetched.count == 1)

        let fetchedTx = try #require(txFetched.first)
        #expect(fetchedTx.payee == "Landlord")
        #expect(fetchedTx.notes == "March rent")
        #expect(fetchedTx.entries.count == 2)

        let debitEntries = fetchedTx.entries.filter { $0.type == .debit }
        let creditEntries = fetchedTx.entries.filter { $0.type == .credit }
        #expect(debitEntries.count == 1)
        #expect(creditEntries.count == 1)

        let fetchedDebit = try #require(debitEntries.first)
        #expect(fetchedDebit.amount == 1500.00)
        #expect(fetchedDebit.account?.name == "Rent")

        let fetchedCredit = try #require(creditEntries.first)
        #expect(fetchedCredit.amount == 1500.00)
        #expect(fetchedCredit.account?.name == "Checking")

        // Verify account entries back-reference
        let accountDescriptor = FetchDescriptor<Account>()
        let accounts = try context.fetch(accountDescriptor)
        let checkingFetched = try #require(accounts.first(where: { $0.name == "Checking" }))
        let rentFetched = try #require(accounts.first(where: { $0.name == "Rent" }))
        #expect(checkingFetched.entries.count == 1)
        #expect(rentFetched.entries.count == 1)
    }

    @Test @MainActor func cascadeDeleteRemovesEntriesWithTransaction() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)

        let account = Account(name: "Checking", type: .asset)
        context.insert(account)

        let transaction = Transaction(date: Date(), payee: "Test")
        context.insert(transaction)

        let entry = Entry(account: account, amount: 50.00, type: .debit)
        context.insert(entry)
        transaction.entries.append(entry)
        entry.transaction = transaction

        try context.save()

        // Confirm entry exists
        let entryDescriptor = FetchDescriptor<Entry>()
        let before = try context.fetch(entryDescriptor)
        #expect(before.count == 1)

        // Delete the transaction — cascade should remove entries
        context.delete(transaction)
        try context.save()

        let after = try context.fetch(entryDescriptor)
        #expect(after.isEmpty)
    }
}

import Foundation
import Testing
import SwiftData
@testable import ShillingCore

@Suite("BalanceService")
struct BalanceServiceTests {

    // MARK: - Helpers

    @MainActor
    private func makeServices() throws -> (ModelContext, TransactionService, BalanceService) {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let txService = TransactionService(context: context)
        let balService = BalanceService(context: context)
        return (context, txService, balService)
    }

    // MARK: - balance(for:) — debit-normal accounts

    @Test @MainActor
    func assetAccountDebitIncreasesBalance() throws {
        let (context, txService, balService) = try makeServices()

        let checking = Account(name: "Checking", type: .asset)
        let equity = Account(name: "Opening Balances", type: .equity)
        context.insert(checking)
        context.insert(equity)

        // Deposit $1000: debit Checking, credit Opening Balances
        try txService.createTransaction(date: Date(), payee: "Opening Balance", entries: [
            EntryData(account: checking, amount: 1000.00, type: .debit),
            EntryData(account: equity, amount: 1000.00, type: .credit),
        ])

        #expect(balService.balance(for: checking) == 1000.00)
    }

    @Test @MainActor
    func assetAccountCreditDecreasesBalance() throws {
        let (context, txService, balService) = try makeServices()

        let checking = Account(name: "Checking", type: .asset)
        let groceries = Account(name: "Groceries", type: .expense)
        let equity = Account(name: "Opening Balances", type: .equity)
        context.insert(checking)
        context.insert(groceries)
        context.insert(equity)

        // Open with $500
        try txService.createTransaction(date: Date(), payee: "Opening Balance", entries: [
            EntryData(account: checking, amount: 500.00, type: .debit),
            EntryData(account: equity, amount: 500.00, type: .credit),
        ])

        // Spend $75: credit Checking (reduces asset), debit Groceries
        try txService.createTransaction(date: Date(), payee: "Whole Foods", entries: [
            EntryData(account: groceries, amount: 75.00, type: .debit),
            EntryData(account: checking, amount: 75.00, type: .credit),
        ])

        #expect(balService.balance(for: checking) == 425.00)
    }

    // MARK: - balance(for:) — credit-normal accounts

    @Test @MainActor
    func liabilityAccountCreditIncreasesBalance() throws {
        let (context, txService, balService) = try makeServices()

        let creditCard = Account(name: "Credit Card", type: .liability)
        let groceries = Account(name: "Groceries", type: .expense)
        context.insert(creditCard)
        context.insert(groceries)

        // Charge $200: debit Groceries, credit Credit Card (increases liability)
        try txService.createTransaction(date: Date(), payee: "Superstore", entries: [
            EntryData(account: groceries, amount: 200.00, type: .debit),
            EntryData(account: creditCard, amount: 200.00, type: .credit),
        ])

        #expect(balService.balance(for: creditCard) == 200.00)
    }

    @Test @MainActor
    func liabilityAccountDebitDecreasesBalance() throws {
        let (context, txService, balService) = try makeServices()

        let creditCard = Account(name: "Credit Card", type: .liability)
        let groceries = Account(name: "Groceries", type: .expense)
        let checking = Account(name: "Checking", type: .asset)
        context.insert(creditCard)
        context.insert(groceries)
        context.insert(checking)

        // Charge $500
        try txService.createTransaction(date: Date(), payee: "Amazon", entries: [
            EntryData(account: groceries, amount: 500.00, type: .debit),
            EntryData(account: creditCard, amount: 500.00, type: .credit),
        ])

        // Pay off $200: debit Credit Card (reduces liability), credit Checking
        try txService.createTransaction(date: Date(), payee: "Payment", entries: [
            EntryData(account: creditCard, amount: 200.00, type: .debit),
            EntryData(account: checking, amount: 200.00, type: .credit),
        ])

        #expect(balService.balance(for: creditCard) == 300.00)
    }

    @Test @MainActor
    func expenseAccountBalanceComputedCorrectly() throws {
        let (context, txService, balService) = try makeServices()

        let groceries = Account(name: "Groceries", type: .expense)
        let checking = Account(name: "Checking", type: .asset)
        context.insert(groceries)
        context.insert(checking)

        try txService.createTransaction(date: Date(), payee: "Shop A", entries: [
            EntryData(account: groceries, amount: 120.00, type: .debit),
            EntryData(account: checking, amount: 120.00, type: .credit),
        ])
        try txService.createTransaction(date: Date(), payee: "Shop B", entries: [
            EntryData(account: groceries, amount: 80.00, type: .debit),
            EntryData(account: checking, amount: 80.00, type: .credit),
        ])

        // Expense is debit-normal: sum of debits
        #expect(balService.balance(for: groceries) == 200.00)
    }

    @Test @MainActor
    func incomeAccountBalanceComputedCorrectly() throws {
        let (context, txService, balService) = try makeServices()

        let salary = Account(name: "Salary", type: .income)
        let checking = Account(name: "Checking", type: .asset)
        context.insert(salary)
        context.insert(checking)

        try txService.createTransaction(date: Date(), payee: "Employer", entries: [
            EntryData(account: checking, amount: 3000.00, type: .debit),
            EntryData(account: salary, amount: 3000.00, type: .credit),
        ])

        // Income is credit-normal: sum of credits
        #expect(balService.balance(for: salary) == 3000.00)
    }

    // MARK: - Account with no entries

    @Test @MainActor
    func accountWithNoEntriesHasZeroBalance() throws {
        let (context, _, balService) = try makeServices()

        let checking = Account(name: "Checking", type: .asset)
        context.insert(checking)

        #expect(balService.balance(for: checking) == 0)
    }

    // MARK: - rollupBalance(for:)

    @Test @MainActor
    func rollupBalanceIncludesEntriesAcrossMultipleHierarchyLevels() throws {
        let (context, txService, balService) = try makeServices()

        let assets = Account(name: "Assets", type: .asset)
        let cash = Account(name: "Cash", type: .asset, parent: assets)
        let wallet = Account(name: "Wallet", type: .asset, parent: cash)
        let equity = Account(name: "Opening Balances", type: .equity)
        context.insert(assets)
        context.insert(cash)
        context.insert(wallet)
        context.insert(equity)

        try txService.createTransaction(date: Date(), payee: "Root Funding", entries: [
            EntryData(account: assets, amount: 100.00, type: .debit),
            EntryData(account: equity, amount: 100.00, type: .credit),
        ])
        try txService.createTransaction(date: Date(), payee: "Cash Funding", entries: [
            EntryData(account: cash, amount: 250.00, type: .debit),
            EntryData(account: equity, amount: 250.00, type: .credit),
        ])
        try txService.createTransaction(date: Date(), payee: "Wallet Funding", entries: [
            EntryData(account: wallet, amount: 50.00, type: .debit),
            EntryData(account: equity, amount: 50.00, type: .credit),
        ])

        #expect(balService.balance(for: assets) == 100.00)
        #expect(balService.balance(for: cash) == 250.00)
        #expect(balService.balance(for: wallet) == 50.00)

        #expect(balService.rollupBalance(for: assets) == 400.00)
        #expect(balService.rollupBalance(for: cash) == 300.00)
        #expect(balService.rollupBalance(for: wallet) == 50.00)
    }

    @Test @MainActor
    func rollupBalancePreservesNonRollupParentBehavior() throws {
        let (context, txService, balService) = try makeServices()

        let parent = Account(name: "Current Assets", type: .asset)
        let child = Account(name: "Checking", type: .asset, parent: parent)
        let equity = Account(name: "Opening Balances", type: .equity)
        context.insert(parent)
        context.insert(child)
        context.insert(equity)

        try txService.createTransaction(date: Date(), payee: "Child Funding", entries: [
            EntryData(account: child, amount: 500.00, type: .debit),
            EntryData(account: equity, amount: 500.00, type: .credit),
        ])

        #expect(balService.balance(for: parent) == 0.00)
        #expect(balService.rollupBalance(for: parent) == 500.00)
    }

    // MARK: - balance(for:asOf:)

    @Test @MainActor
    func balanceAsOfDateFiltersCorrectly() throws {
        let (context, txService, balService) = try makeServices()

        let checking = Account(name: "Checking", type: .asset)
        let groceries = Account(name: "Groceries", type: .expense)
        let equity = Account(name: "Opening Balances", type: .equity)
        context.insert(checking)
        context.insert(groceries)
        context.insert(equity)

        let jan1 = Date(timeIntervalSince1970: 1_735_689_600) // 2025-01-01
        let feb1 = Date(timeIntervalSince1970: 1_738_368_000) // 2025-02-01
        let mar1 = Date(timeIntervalSince1970: 1_740_787_200) // 2025-03-01

        // $1000 opening on Jan 1
        try txService.createTransaction(date: jan1, payee: "Opening Balance", entries: [
            EntryData(account: checking, amount: 1000.00, type: .debit),
            EntryData(account: equity, amount: 1000.00, type: .credit),
        ])

        // -$200 spend on Feb 1
        try txService.createTransaction(date: feb1, payee: "February Spend", entries: [
            EntryData(account: groceries, amount: 200.00, type: .debit),
            EntryData(account: checking, amount: 200.00, type: .credit),
        ])

        // -$300 spend on Mar 1
        try txService.createTransaction(date: mar1, payee: "March Spend", entries: [
            EntryData(account: groceries, amount: 300.00, type: .debit),
            EntryData(account: checking, amount: 300.00, type: .credit),
        ])

        // As of Jan 1: only opening balance
        #expect(balService.balance(for: checking, asOf: jan1) == 1000.00)

        // As of Feb 1: opening + February spend
        #expect(balService.balance(for: checking, asOf: feb1) == 800.00)

        // As of Feb 28 (before Mar 1): still 800
        let feb28 = Date(timeIntervalSince1970: 1_740_700_799)
        #expect(balService.balance(for: checking, asOf: feb28) == 800.00)

        // As of Mar 1: all three transactions
        #expect(balService.balance(for: checking, asOf: mar1) == 500.00)
    }

    @Test @MainActor
    func balanceAsOfDateExcludesTransactionsAfterDate() throws {
        let (context, txService, balService) = try makeServices()

        let checking = Account(name: "Checking", type: .asset)
        let equity = Account(name: "Opening Balances", type: .equity)
        context.insert(checking)
        context.insert(equity)

        let pastDate = Date(timeIntervalSince1970: 1_000_000_000) // ~2001
        let futureDate = Date(timeIntervalSince1970: 2_000_000_000) // ~2033

        try txService.createTransaction(date: futureDate, payee: "Future Deposit", entries: [
            EntryData(account: checking, amount: 500.00, type: .debit),
            EntryData(account: equity, amount: 500.00, type: .credit),
        ])

        // As of pastDate, the future transaction is excluded
        #expect(balService.balance(for: checking, asOf: pastDate) == 0)
    }

    // MARK: - rollupBalance(for:asOf:)

    @Test @MainActor
    func rollupBalanceAsOfDateIncludesOnlyMatchingDescendantEntries() throws {
        let (context, txService, balService) = try makeServices()

        let assets = Account(name: "Assets", type: .asset)
        let checking = Account(name: "Checking", type: .asset, parent: assets)
        let savings = Account(name: "Savings", type: .asset, parent: checking)
        let equity = Account(name: "Opening Balances", type: .equity)
        context.insert(assets)
        context.insert(checking)
        context.insert(savings)
        context.insert(equity)

        let jan1 = Date(timeIntervalSince1970: 1_735_689_600) // 2025-01-01
        let mar1 = Date(timeIntervalSince1970: 1_740_787_200) // 2025-03-01
        let may1 = Date(timeIntervalSince1970: 1_746_057_600) // 2025-05-01

        try txService.createTransaction(date: jan1, payee: "Checking Funding", entries: [
            EntryData(account: checking, amount: 100.00, type: .debit),
            EntryData(account: equity, amount: 100.00, type: .credit),
        ])
        try txService.createTransaction(date: mar1, payee: "Savings Funding", entries: [
            EntryData(account: savings, amount: 200.00, type: .debit),
            EntryData(account: equity, amount: 200.00, type: .credit),
        ])
        try txService.createTransaction(date: may1, payee: "Root Funding", entries: [
            EntryData(account: assets, amount: 50.00, type: .debit),
            EntryData(account: equity, amount: 50.00, type: .credit),
        ])

        let feb1 = Date(timeIntervalSince1970: 1_738_368_000) // 2025-02-01
        let apr1 = Date(timeIntervalSince1970: 1_743_465_600) // 2025-04-01
        let jun1 = Date(timeIntervalSince1970: 1_748_649_600) // 2025-06-01

        #expect(balService.rollupBalance(for: assets, asOf: feb1) == 100.00)
        #expect(balService.rollupBalance(for: assets, asOf: apr1) == 300.00)
        #expect(balService.rollupBalance(for: assets, asOf: jun1) == 350.00)
        #expect(balService.rollupBalance(for: checking, asOf: apr1) == 300.00)
    }

    // MARK: - allBalances(asOf:)

    @Test @MainActor
    func allBalancesReturnsCorrectValuesForMultipleAccounts() throws {
        let (context, txService, balService) = try makeServices()

        let checking = Account(name: "Checking", type: .asset)
        let savings = Account(name: "Savings", type: .asset)
        let groceries = Account(name: "Groceries", type: .expense)
        context.insert(checking)
        context.insert(savings)
        context.insert(groceries)

        // Fund checking with $2000
        let equity = Account(name: "Opening Balances", type: .equity)
        context.insert(equity)
        try txService.createTransaction(date: Date(), payee: "Opening Balance", entries: [
            EntryData(account: checking, amount: 2000.00, type: .debit),
            EntryData(account: equity, amount: 2000.00, type: .credit),
        ])

        // Transfer $500 to savings
        try txService.createTransaction(date: Date(), payee: "Transfer", entries: [
            EntryData(account: savings, amount: 500.00, type: .debit),
            EntryData(account: checking, amount: 500.00, type: .credit),
        ])

        // Spend $150 on groceries
        try txService.createTransaction(date: Date(), payee: "Grocery Run", entries: [
            EntryData(account: groceries, amount: 150.00, type: .debit),
            EntryData(account: checking, amount: 150.00, type: .credit),
        ])

        let results = try balService.allBalances(asOf: nil)

        // Results are sorted by account name
        let names = results.map(\.account.name)
        #expect(names == names.sorted())

        let byName = Dictionary(uniqueKeysWithValues: results.map { ($0.account.name, $0.balance) })
        #expect(byName["Checking"] == 1350.00)  // 2000 - 500 - 150
        #expect(byName["Savings"] == 500.00)
        #expect(byName["Groceries"] == 150.00)
    }

    @Test @MainActor
    func allBalancesExcludesArchivedAccounts() throws {
        let (context, txService, balService) = try makeServices()

        let active = Account(name: "Active", type: .asset)
        let archived = Account(name: "Archived", type: .asset, isArchived: true)
        let equity = Account(name: "Equity", type: .equity)
        context.insert(active)
        context.insert(archived)
        context.insert(equity)

        try txService.createTransaction(date: Date(), payee: "Deposit", entries: [
            EntryData(account: active, amount: 100.00, type: .debit),
            EntryData(account: equity, amount: 100.00, type: .credit),
        ])

        let results = try balService.allBalances(asOf: nil)
        let names = results.map(\.account.name)
        #expect(!names.contains("Archived"))
    }

    @Test @MainActor
    func allBalancesWithDateFiltersCorrectly() throws {
        let (context, txService, balService) = try makeServices()

        let checking = Account(name: "Checking", type: .asset)
        let equity = Account(name: "Opening Balances", type: .equity)
        context.insert(checking)
        context.insert(equity)

        let jan1 = Date(timeIntervalSince1970: 1_735_689_600) // 2025-01-01
        let mar1 = Date(timeIntervalSince1970: 1_740_787_200) // 2025-03-01

        try txService.createTransaction(date: jan1, payee: "Jan Deposit", entries: [
            EntryData(account: checking, amount: 1000.00, type: .debit),
            EntryData(account: equity, amount: 1000.00, type: .credit),
        ])
        try txService.createTransaction(date: mar1, payee: "Mar Deposit", entries: [
            EntryData(account: checking, amount: 500.00, type: .debit),
            EntryData(account: equity, amount: 500.00, type: .credit),
        ])

        let feb1 = Date(timeIntervalSince1970: 1_738_368_000) // 2025-02-01
        let results = try balService.allBalances(asOf: feb1)
        let byName = Dictionary(uniqueKeysWithValues: results.map { ($0.account.name, $0.balance) })

        // Only the January transaction should be included
        #expect(byName["Checking"] == 1000.00)
    }

    // MARK: - runningBalance(for:)

    @Test @MainActor
    func runningBalanceAccumulatesCorrectlyOverMultipleTransactions() throws {
        let (context, txService, balService) = try makeServices()

        let checking = Account(name: "Checking", type: .asset)
        let groceries = Account(name: "Groceries", type: .expense)
        let equity = Account(name: "Opening Balances", type: .equity)
        context.insert(checking)
        context.insert(groceries)
        context.insert(equity)

        let day1 = Date(timeIntervalSince1970: 1_735_689_600)
        let day2 = Date(timeIntervalSince1970: 1_735_776_000)
        let day3 = Date(timeIntervalSince1970: 1_735_862_400)

        try txService.createTransaction(date: day1, payee: "Opening", entries: [
            EntryData(account: checking, amount: 1000.00, type: .debit),
            EntryData(account: equity, amount: 1000.00, type: .credit),
        ])
        try txService.createTransaction(date: day2, payee: "Groceries", entries: [
            EntryData(account: groceries, amount: 100.00, type: .debit),
            EntryData(account: checking, amount: 100.00, type: .credit),
        ])
        try txService.createTransaction(date: day3, payee: "More Groceries", entries: [
            EntryData(account: groceries, amount: 50.00, type: .debit),
            EntryData(account: checking, amount: 50.00, type: .credit),
        ])

        let register = try balService.runningBalance(for: checking)

        #expect(register.count == 3)

        // Sorted by date ascending
        let balances = register.map(\.balance)
        #expect(balances[0] == 1000.00)  // after opening
        #expect(balances[1] == 900.00)   // after groceries spend
        #expect(balances[2] == 850.00)   // after more groceries
    }

    @Test @MainActor
    func runningBalanceForAccountWithNoTransactionsIsEmpty() throws {
        let (context, _, balService) = try makeServices()

        let checking = Account(name: "Checking", type: .asset)
        context.insert(checking)

        let register = try balService.runningBalance(for: checking)
        #expect(register.isEmpty)
    }

    @Test @MainActor
    func runningBalanceOnlyIncludesTransactionsTouchingAccount() throws {
        let (context, txService, balService) = try makeServices()

        let checking = Account(name: "Checking", type: .asset)
        let savings = Account(name: "Savings", type: .asset)
        let groceries = Account(name: "Groceries", type: .expense)
        let equity = Account(name: "Opening Balances", type: .equity)
        context.insert(checking)
        context.insert(savings)
        context.insert(groceries)
        context.insert(equity)

        let day1 = Date(timeIntervalSince1970: 1_735_689_600)
        let day2 = Date(timeIntervalSince1970: 1_735_776_000)

        // Transaction touching both checking and equity
        try txService.createTransaction(date: day1, payee: "Deposit to Checking", entries: [
            EntryData(account: checking, amount: 500.00, type: .debit),
            EntryData(account: equity, amount: 500.00, type: .credit),
        ])

        // Transaction touching only savings (not checking)
        try txService.createTransaction(date: day2, payee: "Deposit to Savings", entries: [
            EntryData(account: savings, amount: 300.00, type: .debit),
            EntryData(account: equity, amount: 300.00, type: .credit),
        ])

        let register = try balService.runningBalance(for: checking)

        // Only the transaction touching checking should appear
        #expect(register.count == 1)
        #expect(register[0].transaction.payee == "Deposit to Checking")
        #expect(register[0].balance == 500.00)
    }

    @Test @MainActor
    func runningBalanceIsSortedByDateAscending() throws {
        let (context, txService, balService) = try makeServices()

        let checking = Account(name: "Checking", type: .asset)
        let equity = Account(name: "Opening Balances", type: .equity)
        context.insert(checking)
        context.insert(equity)

        // Insert in reverse date order
        let day3 = Date(timeIntervalSince1970: 1_735_862_400)
        let day1 = Date(timeIntervalSince1970: 1_735_689_600)
        let day2 = Date(timeIntervalSince1970: 1_735_776_000)

        try txService.createTransaction(date: day3, payee: "Third", entries: [
            EntryData(account: checking, amount: 30.00, type: .debit),
            EntryData(account: equity, amount: 30.00, type: .credit),
        ])
        try txService.createTransaction(date: day1, payee: "First", entries: [
            EntryData(account: checking, amount: 10.00, type: .debit),
            EntryData(account: equity, amount: 10.00, type: .credit),
        ])
        try txService.createTransaction(date: day2, payee: "Second", entries: [
            EntryData(account: checking, amount: 20.00, type: .debit),
            EntryData(account: equity, amount: 20.00, type: .credit),
        ])

        let register = try balService.runningBalance(for: checking)

        let payees = register.map(\.transaction.payee)
        #expect(payees == ["First", "Second", "Third"])

        let balances = register.map(\.balance)
        #expect(balances == [10.00, 30.00, 60.00])
    }
}

import Foundation
import Testing
import SwiftData
@testable import ShillingCore

@Suite("ReportService")
struct ReportServiceTests {

    // MARK: - Helpers

    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainerSetup.makeInMemory()
        return ModelContext(container)
    }

    @MainActor
    private func createAccounts(_ context: ModelContext) -> (checking: Account, savings: Account, creditCard: Account, salary: Account, groceries: Account, rent: Account, equity: Account) {
        let checking = Account(name: "Checking", type: .asset)
        let savings = Account(name: "Savings", type: .asset)
        let creditCard = Account(name: "Credit Card", type: .liability)
        let salary = Account(name: "Salary", type: .income)
        let groceries = Account(name: "Groceries", type: .expense)
        let rent = Account(name: "Rent", type: .expense)
        let equity = Account(name: "Opening Balances", type: .equity)

        for a in [checking, savings, creditCard, salary, groceries, rent, equity] {
            context.insert(a)
        }
        return (checking, savings, creditCard, salary, groceries, rent, equity)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Net Worth History

    @Test @MainActor
    func netWorthHistoryWithNoData() throws {
        let context = try makeContext()
        let service = ReportService(context: context)
        let snapshots = try service.netWorthHistory(months: 3)

        #expect(snapshots.count == 3)
        for snapshot in snapshots {
            #expect(snapshot.assets == .zero)
            #expect(snapshot.liabilities == .zero)
            #expect(snapshot.netWorth == .zero)
        }
    }

    @Test @MainActor
    func netWorthHistoryComputesAssetsAndLiabilities() throws {
        let context = try makeContext()
        let accounts = createAccounts(context)
        let txService = TransactionService(context: context)

        // Create an opening balance 3 months ago
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        let components = Calendar.current.dateComponents([.year, .month], from: threeMonthsAgo)
        let txDate = Calendar.current.date(from: DateComponents(year: components.year, month: components.month, day: 15))!

        try txService.createTransaction(date: txDate, payee: "Opening Balance", entries: [
            EntryData(account: accounts.checking, amount: 5000, type: .debit),
            EntryData(account: accounts.equity, amount: 5000, type: .credit),
        ])

        try txService.createTransaction(date: txDate, payee: "Credit Card Balance", entries: [
            EntryData(account: accounts.groceries, amount: 1000, type: .debit),
            EntryData(account: accounts.creditCard, amount: 1000, type: .credit),
        ])

        let service = ReportService(context: context)
        let snapshots = try service.netWorthHistory(months: 6)

        #expect(snapshots.count == 6)

        // Earlier months before the transactions should have zero
        // The month with the transaction and after should show balances
        let snapshotsWithData = snapshots.filter { $0.netWorth != .zero }
        #expect(!snapshotsWithData.isEmpty)

        // All snapshots with data should show assets=5000, liabilities=1000, net=4000
        for snapshot in snapshotsWithData {
            #expect(snapshot.assets == 5000)
            #expect(snapshot.liabilities == 1000)
            #expect(snapshot.netWorth == 4000)
        }
    }

    // MARK: - Cash Flow

    @Test @MainActor
    func cashFlowWithNoData() throws {
        let context = try makeContext()
        let service = ReportService(context: context)
        let months = try service.cashFlow(months: 3)

        #expect(months.count == 3)
        for month in months {
            #expect(month.income == .zero)
            #expect(month.expenses == .zero)
            #expect(month.net == .zero)
        }
    }

    @Test @MainActor
    func cashFlowSumsIncomeAndExpenses() throws {
        let context = try makeContext()
        let accounts = createAccounts(context)
        let txService = TransactionService(context: context)

        // Create transactions in the current month
        let now = Date()
        let components = Calendar.current.dateComponents([.year, .month], from: now)
        let txDate = Calendar.current.date(from: DateComponents(year: components.year, month: components.month, day: 10))!

        // Salary income: debit Checking, credit Salary
        try txService.createTransaction(date: txDate, payee: "Paycheck", entries: [
            EntryData(account: accounts.checking, amount: 3000, type: .debit),
            EntryData(account: accounts.salary, amount: 3000, type: .credit),
        ])

        // Groceries expense: debit Groceries, credit Checking
        try txService.createTransaction(date: txDate, payee: "Grocery Store", entries: [
            EntryData(account: accounts.groceries, amount: 200, type: .debit),
            EntryData(account: accounts.checking, amount: 200, type: .credit),
        ])

        // Rent expense: debit Rent, credit Checking
        try txService.createTransaction(date: txDate, payee: "Landlord", entries: [
            EntryData(account: accounts.rent, amount: 1500, type: .debit),
            EntryData(account: accounts.checking, amount: 1500, type: .credit),
        ])

        let service = ReportService(context: context)
        let results = try service.cashFlow(months: 1)

        #expect(results.count == 1)
        #expect(results[0].income == 3000)
        #expect(results[0].expenses == 1700)
        #expect(results[0].net == 1300)
    }

    @Test @MainActor
    func cashFlowSeparatesMonths() throws {
        let context = try makeContext()
        let accounts = createAccounts(context)
        let txService = TransactionService(context: context)

        let now = Date()
        let cal = Calendar.current
        let currentComponents = cal.dateComponents([.year, .month], from: now)
        let thisMonth = cal.date(from: DateComponents(year: currentComponents.year, month: currentComponents.month, day: 5))!

        guard let lastMonth = cal.date(byAdding: .month, value: -1, to: thisMonth) else {
            Issue.record("Could not compute last month date")
            return
        }

        // Last month: income of 2000
        try txService.createTransaction(date: lastMonth, payee: "Paycheck", entries: [
            EntryData(account: accounts.checking, amount: 2000, type: .debit),
            EntryData(account: accounts.salary, amount: 2000, type: .credit),
        ])

        // This month: income of 3000
        try txService.createTransaction(date: thisMonth, payee: "Paycheck", entries: [
            EntryData(account: accounts.checking, amount: 3000, type: .debit),
            EntryData(account: accounts.salary, amount: 3000, type: .credit),
        ])

        let service = ReportService(context: context)
        let results = try service.cashFlow(months: 2)

        #expect(results.count == 2)
        #expect(results[0].income == 2000) // last month
        #expect(results[1].income == 3000) // this month
    }

    // MARK: - Balance Sheet

    @Test @MainActor
    func balanceSheetWithNoData() throws {
        let context = try makeContext()
        let service = ReportService(context: context)
        let sheet = try service.balanceSheet(asOf: Date())

        #expect(sheet.assets.isEmpty)
        #expect(sheet.liabilities.isEmpty)
        #expect(sheet.equity.isEmpty)
        #expect(sheet.netWorth == .zero)
    }

    @Test @MainActor
    func balanceSheetGroupsByAccountType() throws {
        let context = try makeContext()
        let accounts = createAccounts(context)
        let txService = TransactionService(context: context)

        let txDate = date(year: 2026, month: 1, day: 15)

        // Opening balance: Checking gets 10000
        try txService.createTransaction(date: txDate, payee: "Opening Balance", entries: [
            EntryData(account: accounts.checking, amount: 10000, type: .debit),
            EntryData(account: accounts.equity, amount: 10000, type: .credit),
        ])

        // Savings gets 5000
        try txService.createTransaction(date: txDate, payee: "Transfer", entries: [
            EntryData(account: accounts.savings, amount: 5000, type: .debit),
            EntryData(account: accounts.checking, amount: 5000, type: .credit),
        ])

        // Credit card liability
        try txService.createTransaction(date: txDate, payee: "Purchase", entries: [
            EntryData(account: accounts.groceries, amount: 300, type: .debit),
            EntryData(account: accounts.creditCard, amount: 300, type: .credit),
        ])

        let service = ReportService(context: context)
        let sheet = try service.balanceSheet(asOf: date(year: 2026, month: 3, day: 1))

        // Assets: Checking=5000, Savings=5000
        #expect(sheet.assets.count == 2)
        #expect(sheet.totalAssets == 10000)

        // Liabilities: Credit Card=300
        #expect(sheet.liabilities.count == 1)
        #expect(sheet.totalLiabilities == 300)

        // Equity: Opening Balances=10000
        #expect(sheet.equity.count == 1)
        #expect(sheet.totalEquity == 10000)

        #expect(sheet.netWorth == 9700)
    }

    @Test @MainActor
    func balanceSheetExcludesZeroBalanceAccounts() throws {
        let context = try makeContext()
        let _ = createAccounts(context)

        let service = ReportService(context: context)
        let sheet = try service.balanceSheet(asOf: Date())

        // All accounts have zero balance, so all groups should be empty
        #expect(sheet.assets.isEmpty)
        #expect(sheet.liabilities.isEmpty)
        #expect(sheet.equity.isEmpty)
    }

    @Test @MainActor
    func balanceSheetRespectsAsOfDate() throws {
        let context = try makeContext()
        let accounts = createAccounts(context)
        let txService = TransactionService(context: context)

        // Transaction in January
        try txService.createTransaction(date: date(year: 2026, month: 1, day: 15), payee: "Opening", entries: [
            EntryData(account: accounts.checking, amount: 5000, type: .debit),
            EntryData(account: accounts.equity, amount: 5000, type: .credit),
        ])

        // Transaction in March
        try txService.createTransaction(date: date(year: 2026, month: 3, day: 15), payee: "Deposit", entries: [
            EntryData(account: accounts.checking, amount: 2000, type: .debit),
            EntryData(account: accounts.equity, amount: 2000, type: .credit),
        ])

        let service = ReportService(context: context)

        // As of end of Feb, should only see 5000
        let febSheet = try service.balanceSheet(asOf: date(year: 2026, month: 2, day: 28))
        let febChecking = febSheet.assets.first { $0.account.name == "Checking" }
        #expect(febChecking?.balance == 5000)

        // As of end of March, should see 7000
        let marSheet = try service.balanceSheet(asOf: date(year: 2026, month: 3, day: 31))
        let marChecking = marSheet.assets.first { $0.account.name == "Checking" }
        #expect(marChecking?.balance == 7000)
    }
}

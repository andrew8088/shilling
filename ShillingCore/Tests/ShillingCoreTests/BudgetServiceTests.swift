import Foundation
import Testing
import SwiftData
@testable import ShillingCore

@Suite("BudgetService")
struct BudgetServiceTests {

    // MARK: - Helpers

    @MainActor
    private func makeServices() throws -> (ModelContext, TransactionService, BudgetService) {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let txService = TransactionService(context: context)
        let budgetService = BudgetService(context: context)
        return (context, txService, budgetService)
    }

    /// Returns a Date at midnight UTC for the given year/month/day.
    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12 // noon local to avoid midnight boundary edge cases
        return Calendar.current.date(from: components)!
    }

    // MARK: - setBudget

    @Test @MainActor
    func setBudgetForExpenseAccountSucceeds() throws {
        let (context, _, budgetService) = try makeServices()

        let groceries = Account(name: "Groceries", type: .expense)
        context.insert(groceries)

        let budget = try budgetService.setBudget(account: groceries, year: 2025, month: 3, amount: 400.00)

        #expect(budget.amount == 400.00)
        #expect(budget.year == 2025)
        #expect(budget.month == 3)
        #expect(budget.account?.id == groceries.id)
    }

    @Test @MainActor
    func setBudgetForNonExpenseAccountThrows() throws {
        let (context, _, budgetService) = try makeServices()

        let checking = Account(name: "Checking", type: .asset)
        context.insert(checking)

        #expect(throws: BudgetError.notExpenseAccount) {
            try budgetService.setBudget(account: checking, year: 2025, month: 3, amount: 500.00)
        }
    }

    @Test @MainActor
    func setBudgetUpdatesExistingBudgetNoDuplicate() throws {
        let (context, _, budgetService) = try makeServices()

        let dining = Account(name: "Dining", type: .expense)
        context.insert(dining)

        let first = try budgetService.setBudget(account: dining, year: 2025, month: 4, amount: 200.00)
        #expect(first.amount == 200.00)

        let second = try budgetService.setBudget(account: dining, year: 2025, month: 4, amount: 300.00)
        #expect(second.amount == 300.00)
        #expect(second.id == first.id) // same object — no duplicate created

        // Confirm only one budget exists in store
        let fetched = try budgetService.getBudget(account: dining, year: 2025, month: 4)
        #expect(fetched?.amount == 300.00)
    }

    // MARK: - getBudget

    @Test @MainActor
    func getBudgetReturnsCorrectBudget() throws {
        let (context, _, budgetService) = try makeServices()

        let rent = Account(name: "Rent", type: .expense)
        context.insert(rent)

        try budgetService.setBudget(account: rent, year: 2025, month: 1, amount: 1500.00)

        let fetched = try budgetService.getBudget(account: rent, year: 2025, month: 1)
        #expect(fetched != nil)
        #expect(fetched?.amount == 1500.00)
    }

    @Test @MainActor
    func getBudgetReturnsNilWhenNoneExists() throws {
        let (context, _, budgetService) = try makeServices()

        let utilities = Account(name: "Utilities", type: .expense)
        context.insert(utilities)

        let fetched = try budgetService.getBudget(account: utilities, year: 2025, month: 6)
        #expect(fetched == nil)
    }

    // MARK: - comparison

    @Test @MainActor
    func comparisonReturnsCorrectAmountsWithTransactions() throws {
        let (context, txService, budgetService) = try makeServices()

        let groceries = Account(name: "Groceries", type: .expense)
        let checking = Account(name: "Checking", type: .asset)
        context.insert(groceries)
        context.insert(checking)

        // Set a $400 budget for March 2025
        try budgetService.setBudget(account: groceries, year: 2025, month: 3, amount: 400.00)

        // Spend $150 in March
        try txService.createTransaction(
            date: date(year: 2025, month: 3, day: 5),
            payee: "Whole Foods",
            entries: [
                EntryData(account: groceries, amount: 150.00, type: .debit),
                EntryData(account: checking, amount: 150.00, type: .credit),
            ]
        )

        // Spend $100 in March
        try txService.createTransaction(
            date: date(year: 2025, month: 3, day: 20),
            payee: "Trader Joe's",
            entries: [
                EntryData(account: groceries, amount: 100.00, type: .debit),
                EntryData(account: checking, amount: 100.00, type: .credit),
            ]
        )

        // Spend $200 in a different month (should be excluded)
        try txService.createTransaction(
            date: date(year: 2025, month: 4, day: 1),
            payee: "April Shop",
            entries: [
                EntryData(account: groceries, amount: 200.00, type: .debit),
                EntryData(account: checking, amount: 200.00, type: .credit),
            ]
        )

        let comparison = try budgetService.comparison(account: groceries, year: 2025, month: 3)

        #expect(comparison != nil)
        #expect(comparison?.budgetAmount == 400.00)
        #expect(comparison?.actualAmount == 250.00)   // 150 + 100
        #expect(comparison?.remaining == 150.00)       // 400 - 250 = under budget
    }

    @Test @MainActor
    func comparisonReturnsNilWhenNoBudgetSet() throws {
        let (context, _, budgetService) = try makeServices()

        let entertainment = Account(name: "Entertainment", type: .expense)
        context.insert(entertainment)

        let comparison = try budgetService.comparison(account: entertainment, year: 2025, month: 5)
        #expect(comparison == nil)
    }

    @Test @MainActor
    func remainingIsNegativeWhenOverBudget() throws {
        let (context, txService, budgetService) = try makeServices()

        let dining = Account(name: "Dining", type: .expense)
        let checking = Account(name: "Checking", type: .asset)
        context.insert(dining)
        context.insert(checking)

        // Budget $100 but spend $175
        try budgetService.setBudget(account: dining, year: 2025, month: 7, amount: 100.00)

        try txService.createTransaction(
            date: date(year: 2025, month: 7, day: 10),
            payee: "Restaurant",
            entries: [
                EntryData(account: dining, amount: 175.00, type: .debit),
                EntryData(account: checking, amount: 175.00, type: .credit),
            ]
        )

        let comparison = try budgetService.comparison(account: dining, year: 2025, month: 7)
        #expect(comparison?.remaining == -75.00) // over budget
    }

    @Test @MainActor
    func remainingIsPositiveWhenUnderBudget() throws {
        let (context, txService, budgetService) = try makeServices()

        let transport = Account(name: "Transport", type: .expense)
        let checking = Account(name: "Checking", type: .asset)
        context.insert(transport)
        context.insert(checking)

        // Budget $200 and spend only $80
        try budgetService.setBudget(account: transport, year: 2025, month: 8, amount: 200.00)

        try txService.createTransaction(
            date: date(year: 2025, month: 8, day: 15),
            payee: "Bus Pass",
            entries: [
                EntryData(account: transport, amount: 80.00, type: .debit),
                EntryData(account: checking, amount: 80.00, type: .credit),
            ]
        )

        let comparison = try budgetService.comparison(account: transport, year: 2025, month: 8)
        #expect(comparison?.remaining == 120.00) // under budget
    }

    // MARK: - monthlySummary

    @Test @MainActor
    func monthlySummaryReturnsAllBudgetedAccountsSortedByName() throws {
        let (context, txService, budgetService) = try makeServices()

        let groceries = Account(name: "Groceries", type: .expense)
        let rent = Account(name: "Rent", type: .expense)
        let utilities = Account(name: "Utilities", type: .expense)
        let checking = Account(name: "Checking", type: .asset)
        context.insert(groceries)
        context.insert(rent)
        context.insert(utilities)
        context.insert(checking)

        // Set budgets for February 2025
        try budgetService.setBudget(account: utilities, year: 2025, month: 2, amount: 150.00)
        try budgetService.setBudget(account: rent, year: 2025, month: 2, amount: 2000.00)
        try budgetService.setBudget(account: groceries, year: 2025, month: 2, amount: 500.00)

        // Spend on groceries
        try txService.createTransaction(
            date: date(year: 2025, month: 2, day: 10),
            payee: "Supermarket",
            entries: [
                EntryData(account: groceries, amount: 300.00, type: .debit),
                EntryData(account: checking, amount: 300.00, type: .credit),
            ]
        )

        let summary = try budgetService.monthlySummary(year: 2025, month: 2)

        #expect(summary.count == 3)

        // Verify sorted by account name
        let names = summary.map(\.account.name)
        #expect(names == ["Groceries", "Rent", "Utilities"])

        let byName = Dictionary(uniqueKeysWithValues: summary.map { ($0.account.name, $0) })
        #expect(byName["Groceries"]?.budgetAmount == 500.00)
        #expect(byName["Groceries"]?.actualAmount == 300.00)
        #expect(byName["Groceries"]?.remaining == 200.00)
        #expect(byName["Rent"]?.budgetAmount == 2000.00)
        #expect(byName["Rent"]?.actualAmount == 0.00)
        #expect(byName["Rent"]?.remaining == 2000.00)
        #expect(byName["Utilities"]?.budgetAmount == 150.00)
        #expect(byName["Utilities"]?.actualAmount == 0.00)
    }

    @Test @MainActor
    func monthlySummaryExcludesBudgetsFromOtherMonths() throws {
        let (context, _, budgetService) = try makeServices()

        let groceries = Account(name: "Groceries", type: .expense)
        let rent = Account(name: "Rent", type: .expense)
        context.insert(groceries)
        context.insert(rent)

        // Budget groceries in January, rent in February
        try budgetService.setBudget(account: groceries, year: 2025, month: 1, amount: 400.00)
        try budgetService.setBudget(account: rent, year: 2025, month: 2, amount: 1800.00)

        let januarySummary = try budgetService.monthlySummary(year: 2025, month: 1)
        #expect(januarySummary.count == 1)
        #expect(januarySummary[0].account.name == "Groceries")

        let februarySummary = try budgetService.monthlySummary(year: 2025, month: 2)
        #expect(februarySummary.count == 1)
        #expect(februarySummary[0].account.name == "Rent")
    }
}

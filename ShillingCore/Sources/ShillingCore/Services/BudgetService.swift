import Foundation
import SwiftData

// MARK: - BudgetError

public enum BudgetError: Error, LocalizedError, Equatable {
    case notExpenseAccount

    public var errorDescription: String? {
        switch self {
        case .notExpenseAccount:
            return "Budgets can only be set on expense accounts."
        }
    }
}

// MARK: - BudgetComparison

public struct BudgetComparison {
    public let account: Account
    public let budgetAmount: Decimal
    public let actualAmount: Decimal
    /// budgetAmount - actualAmount. Positive = under budget, negative = over budget.
    public let remaining: Decimal

    public init(account: Account, budgetAmount: Decimal, actualAmount: Decimal) {
        self.account = account
        self.budgetAmount = budgetAmount
        self.actualAmount = actualAmount
        self.remaining = budgetAmount - actualAmount
    }
}

// MARK: - BudgetService

public struct BudgetService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - setBudget(account:year:month:amount:)

    /// Creates or updates the budget target for an expense account in a given month.
    /// Throws `BudgetError.notExpenseAccount` if the account is not an expense account.
    @discardableResult
    public func setBudget(
        account: Account,
        year: Int,
        month: Int,
        amount: Decimal
    ) throws -> Budget {
        guard account.type == .expense else {
            throw BudgetError.notExpenseAccount
        }

        if let existing = try getBudget(account: account, year: year, month: month) {
            existing.amount = amount
            return existing
        }

        let budget = Budget(account: account, year: year, month: month, amount: amount)
        context.insert(budget)
        return budget
    }

    // MARK: - getBudget(account:year:month:)

    /// Returns the budget for the given account/year/month, or nil if none exists.
    public func getBudget(account: Account, year: Int, month: Int) throws -> Budget? {
        let accountID = account.id
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate {
                $0.account?.id == accountID && $0.year == year && $0.month == month
            }
        )
        return try context.fetch(descriptor).first
    }

    // MARK: - comparison(account:year:month:)

    /// Returns a BudgetComparison for the given account/year/month, or nil if no budget is set.
    /// Actual spending is computed from debit entries on the account within the calendar month.
    public func comparison(account: Account, year: Int, month: Int) throws -> BudgetComparison? {
        guard let budget = try getBudget(account: account, year: year, month: month) else {
            return nil
        }

        let actual = actualSpending(account: account, year: year, month: month)
        return BudgetComparison(account: account, budgetAmount: budget.amount, actualAmount: actual)
    }

    // MARK: - monthlySummary(year:month:)

    /// Returns BudgetComparisons for every budget set for the given month, sorted by account name.
    public func monthlySummary(year: Int, month: Int) throws -> [BudgetComparison] {
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.year == year && $0.month == month },
            sortBy: [SortDescriptor(\Budget.month)] // fetch all, sort by account name below
        )
        let budgets = try context.fetch(descriptor)

        return budgets
            .compactMap { budget -> BudgetComparison? in
                guard let account = budget.account else { return nil }
                let actual = actualSpending(account: account, year: year, month: month)
                return BudgetComparison(
                    account: account,
                    budgetAmount: budget.amount,
                    actualAmount: actual
                )
            }
            .sorted { $0.account.name < $1.account.name }
    }

    // MARK: - Private helpers

    /// Sums all debit entries on `account` whose transaction date falls within the given calendar month.
    private func actualSpending(account: Account, year: Int, month: Int) -> Decimal {
        guard
            let startOfMonth = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)),
            let startOfNextMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth)
        else {
            return .zero
        }

        return account.entries
            .filter { entry in
                guard
                    entry.type == .debit,
                    let txDate = entry.transaction?.date
                else { return false }
                return txDate >= startOfMonth && txDate < startOfNextMonth
            }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }
}

import Foundation
import SwiftData

// MARK: - Report Data Types

public struct MonthSnapshot: Sendable {
    public let date: Date
    public let assets: Decimal
    public let liabilities: Decimal
    public let netWorth: Decimal

    public init(date: Date, assets: Decimal, liabilities: Decimal, netWorth: Decimal) {
        self.date = date
        self.assets = assets
        self.liabilities = liabilities
        self.netWorth = netWorth
    }
}

public struct CashFlowMonth: Sendable {
    public let date: Date
    public let income: Decimal
    public let expenses: Decimal
    public let net: Decimal

    public init(date: Date, income: Decimal, expenses: Decimal, net: Decimal) {
        self.date = date
        self.income = income
        self.expenses = expenses
        self.net = net
    }
}

public struct BalanceSheetData {
    public let asOf: Date
    public let assets: [(account: Account, balance: Decimal)]
    public let liabilities: [(account: Account, balance: Decimal)]
    public let equity: [(account: Account, balance: Decimal)]

    public var totalAssets: Decimal { assets.reduce(.zero) { $0 + $1.balance } }
    public var totalLiabilities: Decimal { liabilities.reduce(.zero) { $0 + $1.balance } }
    public var totalEquity: Decimal { equity.reduce(.zero) { $0 + $1.balance } }
    public var netWorth: Decimal { totalAssets - totalLiabilities }

    public init(asOf: Date, assets: [(account: Account, balance: Decimal)],
                liabilities: [(account: Account, balance: Decimal)],
                equity: [(account: Account, balance: Decimal)]) {
        self.asOf = asOf
        self.assets = assets
        self.liabilities = liabilities
        self.equity = equity
    }
}

// MARK: - ReportService

public struct ReportService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Net Worth History

    /// Computes net worth snapshots for the last N month-ends.
    /// Each snapshot shows total assets, liabilities, and net worth as of the last day of that month.
    public func netWorthHistory(months: Int) throws -> [MonthSnapshot] {
        let calendar = Calendar.current
        let now = Date()
        let currentComponents = calendar.dateComponents([.year, .month], from: now)

        var snapshots: [MonthSnapshot] = []

        for i in stride(from: months - 1, through: 0, by: -1) {
            guard let targetMonth = calendar.date(
                byAdding: .month,
                value: -i,
                to: calendar.date(from: currentComponents)!
            ) else { continue }

            // End of target month = start of next month minus 1 second
            guard let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: targetMonth) else { continue }
            let endOfMonth = startOfNextMonth.addingTimeInterval(-1)

            let balances = try BalanceService(context: context).allBalances(asOf: endOfMonth)

            var totalAssets: Decimal = .zero
            var totalLiabilities: Decimal = .zero

            for (account, balance) in balances {
                switch account.type {
                case .asset:
                    totalAssets += balance
                case .liability:
                    totalLiabilities += balance
                default:
                    break
                }
            }

            snapshots.append(MonthSnapshot(
                date: targetMonth,
                assets: totalAssets,
                liabilities: totalLiabilities,
                netWorth: totalAssets - totalLiabilities
            ))
        }

        return snapshots
    }

    // MARK: - Cash Flow

    /// Computes income and expense totals for each of the last N months.
    /// Income = sum of credit entries on income accounts within the month.
    /// Expenses = sum of debit entries on expense accounts within the month.
    public func cashFlow(months: Int) throws -> [CashFlowMonth] {
        let calendar = Calendar.current
        let now = Date()
        let currentComponents = calendar.dateComponents([.year, .month], from: now)

        // Fetch all transactions once
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let allTransactions = try context.fetch(descriptor)

        var results: [CashFlowMonth] = []

        for i in stride(from: months - 1, through: 0, by: -1) {
            guard let startOfMonth = calendar.date(
                byAdding: .month,
                value: -i,
                to: calendar.date(from: currentComponents)!
            ) else { continue }

            guard let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else { continue }

            var income: Decimal = .zero
            var expenses: Decimal = .zero

            for tx in allTransactions {
                guard tx.date >= startOfMonth && tx.date < startOfNextMonth else { continue }

                for entry in tx.entries {
                    guard let account = entry.account else { continue }

                    switch account.type {
                    case .income where entry.type == .credit:
                        income += entry.amount
                    case .expense where entry.type == .debit:
                        expenses += entry.amount
                    default:
                        break
                    }
                }
            }

            results.append(CashFlowMonth(
                date: startOfMonth,
                income: income,
                expenses: expenses,
                net: income - expenses
            ))
        }

        return results
    }

    // MARK: - Balance Sheet

    /// Produces a balance sheet as of the given date, grouping accounts by type.
    /// Only includes accounts with non-zero balances.
    public func balanceSheet(asOf date: Date) throws -> BalanceSheetData {
        let balances = try BalanceService(context: context).allBalances(asOf: date)

        var assets: [(Account, Decimal)] = []
        var liabilities: [(Account, Decimal)] = []
        var equity: [(Account, Decimal)] = []

        for (account, balance) in balances {
            guard balance != .zero else { continue }
            switch account.type {
            case .asset:
                assets.append((account, balance))
            case .liability:
                liabilities.append((account, balance))
            case .equity:
                equity.append((account, balance))
            case .income, .expense:
                // Income and expense are P&L accounts, not balance sheet
                break
            }
        }

        return BalanceSheetData(asOf: date, assets: assets, liabilities: liabilities, equity: equity)
    }
}

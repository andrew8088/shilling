import Foundation
import SwiftData

public struct BalanceService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - balance(for:)

    /// Computes the balance of an account from all its entries.
    ///
    /// Debit-normal accounts (asset, expense): balance = sum(debits) - sum(credits)
    /// Credit-normal accounts (liability, equity, income): balance = sum(credits) - sum(debits)
    public func balance(for account: Account) -> Decimal {
        computeBalance(entries: account.entries, accountType: account.type)
    }

    // MARK: - balance(for:asOf:)

    /// Computes the balance of an account, including only entries from transactions
    /// whose date is on or before `date`.
    public func balance(for account: Account, asOf date: Date) -> Decimal {
        let filtered = account.entries.filter { entry in
            guard let txDate = entry.transaction?.date else { return false }
            return txDate <= date
        }
        return computeBalance(entries: filtered, accountType: account.type)
    }

    // MARK: - allBalances(asOf:)

    /// Returns balances for all non-archived accounts, sorted by account name.
    /// If `date` is nil, all entries are included; otherwise only entries from
    /// transactions on or before `date` are counted.
    public func allBalances(asOf date: Date?) throws -> [(account: Account, balance: Decimal)] {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.name)]
        )
        let accounts = try context.fetch(descriptor)

        return accounts.map { account in
            let bal: Decimal
            if let date {
                bal = balance(for: account, asOf: date)
            } else {
                bal = balance(for: account)
            }
            return (account: account, balance: bal)
        }
    }

    // MARK: - runningBalance(for:)

    /// Returns transactions involving this account sorted by date ascending,
    /// each paired with the cumulative running balance after that transaction.
    public func runningBalance(for account: Account) throws -> [(transaction: Transaction, balance: Decimal)] {
        // Collect transactions that touch this account.
        let accountID = account.id
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let allTransactions = try context.fetch(descriptor)
        let relevant = allTransactions.filter { tx in
            tx.entries.contains { $0.account?.id == accountID }
        }

        var running: Decimal = 0
        return relevant.map { tx in
            // Only the entries that belong to this account contribute to its balance.
            let txEntries = tx.entries.filter { $0.account?.id == accountID }
            let delta = entryDelta(entries: txEntries, accountType: account.type)
            running += delta
            return (transaction: tx, balance: running)
        }
    }

    // MARK: - Private helpers

    /// Computes signed balance contribution for a set of entries under the given account type.
    private func computeBalance(entries: [Entry], accountType: AccountType) -> Decimal {
        let debits = entries.filter { $0.type == .debit }.reduce(Decimal.zero) { $0 + $1.amount }
        let credits = entries.filter { $0.type == .credit }.reduce(Decimal.zero) { $0 + $1.amount }

        if accountType.isDebitNormal {
            return debits - credits
        } else {
            return credits - debits
        }
    }

    /// Returns the signed balance delta for a set of entries (positive = natural balance increase).
    private func entryDelta(entries: [Entry], accountType: AccountType) -> Decimal {
        computeBalance(entries: entries, accountType: accountType)
    }
}

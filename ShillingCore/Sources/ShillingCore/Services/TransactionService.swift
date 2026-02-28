import Foundation
import SwiftData

// MARK: - EntryData

/// A value type for passing entry information into TransactionService.
public struct EntryData {
    public let account: Account
    public let amount: Decimal
    public let type: EntryType
    public let memo: String?

    public init(account: Account, amount: Decimal, type: EntryType, memo: String? = nil) {
        self.account = account
        self.amount = amount
        self.type = type
        self.memo = memo
    }
}

// MARK: - TransactionError

public enum TransactionError: Error, LocalizedError, Equatable {
    case insufficientEntries
    case zeroOrNegativeAmount
    case unbalancedEntries(debitTotal: Decimal, creditTotal: Decimal)

    public var errorDescription: String? {
        switch self {
        case .insufficientEntries:
            return "A transaction must have at least two entries."
        case .zeroOrNegativeAmount:
            return "All entry amounts must be greater than zero."
        case .unbalancedEntries(let debitTotal, let creditTotal):
            return "Transaction is unbalanced: debits \(debitTotal) do not equal credits \(creditTotal)."
        }
    }
}

// MARK: - TransactionService

public struct TransactionService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Validation

    private func validate(entries: [EntryData]) throws {
        guard entries.count >= 2 else {
            throw TransactionError.insufficientEntries
        }

        for entry in entries {
            guard entry.amount > 0 else {
                throw TransactionError.zeroOrNegativeAmount
            }
        }

        let debitTotal = entries
            .filter { $0.type == .debit }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let creditTotal = entries
            .filter { $0.type == .credit }
            .reduce(Decimal.zero) { $0 + $1.amount }

        guard debitTotal == creditTotal else {
            throw TransactionError.unbalancedEntries(debitTotal: debitTotal, creditTotal: creditTotal)
        }
    }

    // MARK: - Create

    /// Creates and persists a new balanced transaction.
    @discardableResult
    public func createTransaction(
        date: Date,
        payee: String,
        notes: String? = nil,
        entries entryData: [EntryData]
    ) throws -> Transaction {
        try validate(entries: entryData)

        let transaction = Transaction(date: date, payee: payee, notes: notes)
        context.insert(transaction)

        for data in entryData {
            let entry = Entry(account: data.account, amount: data.amount, type: data.type, memo: data.memo)
            context.insert(entry)
            entry.transaction = transaction
            transaction.entries.append(entry)
        }

        return transaction
    }

    // MARK: - Update

    /// Replaces all entries on an existing transaction and re-validates.
    public func updateTransaction(
        _ transaction: Transaction,
        date: Date,
        payee: String,
        notes: String? = nil,
        entries entryData: [EntryData]
    ) throws {
        try validate(entries: entryData)

        // Delete old entries.
        for entry in transaction.entries {
            context.delete(entry)
        }
        transaction.entries.removeAll()

        transaction.date = date
        transaction.payee = payee
        transaction.notes = notes

        for data in entryData {
            let entry = Entry(account: data.account, amount: data.amount, type: data.type, memo: data.memo)
            context.insert(entry)
            entry.transaction = transaction
            transaction.entries.append(entry)
        }
    }

    // MARK: - Delete

    /// Deletes a transaction. Cascade delete removes its entries.
    public func deleteTransaction(_ transaction: Transaction) {
        context.delete(transaction)
    }

    // MARK: - Fetch

    /// Fetches transactions filtered by optional date range, account, and payee substring.
    /// Results are sorted by date descending.
    public func fetchTransactions(
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        account: Account? = nil,
        payee: String? = nil
    ) throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let transactions = try context.fetch(descriptor)

        return transactions.filter { transaction in
            if let startDate, transaction.date < startDate { return false }
            if let endDate, transaction.date > endDate { return false }
            if let account {
                let accountID = account.id
                let hasAccount = transaction.entries.contains { $0.account?.id == accountID }
                if !hasAccount { return false }
            }
            if let payee {
                let lowercasedPayee = payee.lowercased()
                if !transaction.payee.lowercased().contains(lowercasedPayee) { return false }
            }
            return true
        }
    }

    // MARK: - Opening Balance

    /// Creates an opening balance transaction for the given account.
    ///
    /// For asset accounts: debit the account, credit Opening Balances equity account.
    /// For liability accounts: credit the account, debit Opening Balances equity account.
    @discardableResult
    public func createOpeningBalance(
        account: Account,
        amount: Decimal,
        date: Date,
        openingBalancesAccount: Account
    ) throws -> Transaction {
        let entryData: [EntryData]

        switch account.type {
        case .asset, .expense:
            // Debit-normal accounts: debit the account to increase it
            entryData = [
                EntryData(account: account, amount: amount, type: .debit),
                EntryData(account: openingBalancesAccount, amount: amount, type: .credit),
            ]
        case .liability, .equity, .income:
            // Credit-normal accounts: credit the account to increase it
            entryData = [
                EntryData(account: openingBalancesAccount, amount: amount, type: .debit),
                EntryData(account: account, amount: amount, type: .credit),
            ]
        }

        return try createTransaction(
            date: date,
            payee: "Opening Balance",
            notes: nil,
            entries: entryData
        )
    }
}

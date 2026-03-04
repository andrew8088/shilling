import Foundation
import SwiftData

// MARK: - ColumnMapping

/// Describes how to map CSV columns to ledger transaction fields.
public struct ColumnMapping {
    public let dateColumn: String
    public let payeeColumn: String
    /// Header name for a signed amount column. Mutually exclusive with debitColumn/creditColumn.
    public let amountColumn: String?
    /// Header name for a debit (outflow) amount column.
    public let debitColumn: String?
    /// Header name for a credit (inflow) amount column.
    public let creditColumn: String?
    /// Optional header name for memo/notes.
    public let memoColumn: String?

    /// Single signed-amount column initialiser.
    public init(
        dateColumn: String,
        payeeColumn: String,
        amountColumn: String,
        memoColumn: String? = nil
    ) {
        self.dateColumn = dateColumn
        self.payeeColumn = payeeColumn
        self.amountColumn = amountColumn
        self.debitColumn = nil
        self.creditColumn = nil
        self.memoColumn = memoColumn
    }

    /// Separate debit/credit columns initialiser.
    public init(
        dateColumn: String,
        payeeColumn: String,
        debitColumn: String,
        creditColumn: String,
        memoColumn: String? = nil
    ) {
        self.dateColumn = dateColumn
        self.payeeColumn = payeeColumn
        self.amountColumn = nil
        self.debitColumn = debitColumn
        self.creditColumn = creditColumn
        self.memoColumn = memoColumn
    }
}

// MARK: - ImportRowError

/// A row-level error encountered during import.
public struct ImportRowError {
    public let lineNumber: Int
    public let message: String

    public init(lineNumber: Int, message: String) {
        self.lineNumber = lineNumber
        self.message = message
    }
}

// MARK: - ImportResult

/// The outcome of a single import operation.
public struct ImportResult {
    public let importRecord: ImportRecord
    public let importedCount: Int
    public let skippedDuplicates: Int
    public let errors: [ImportRowError]

    public init(
        importRecord: ImportRecord,
        importedCount: Int,
        skippedDuplicates: Int,
        errors: [ImportRowError]
    ) {
        self.importRecord = importRecord
        self.importedCount = importedCount
        self.skippedDuplicates = skippedDuplicates
        self.errors = errors
    }
}

// MARK: - ImportService

public struct ImportService {
    private let context: ModelContext
    private static var fingerprintCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private struct TransactionFingerprint: Hashable {
        let date: Date
        let normalizedPayee: String
        let accountID: UUID
        let signedAmount: String
    }

    public init(context: ModelContext) {
        self.context = context
    }

    /// Import parsed CSV rows into the ledger.
    ///
    /// - Parameters:
    ///   - rows: Parsed CSV rows from CSVParser.
    ///   - mapping: Column mapping configuration.
    ///   - account: The target account (one side of each transaction).
    ///   - contraAccount: The default contra account (other side of each transaction).
    ///   - fileName: Original filename for the ImportRecord.
    /// - Returns: ImportResult with counts and any row-level errors.
    public func importRows(
        _ rows: [CSVRow],
        mapping: ColumnMapping,
        account: Account,
        contraAccount: Account,
        fileName: String
    ) throws -> ImportResult {
        // Create the ImportRecord for this batch.
        let importRecord = ImportRecord(fileName: fileName, rowCount: rows.count)
        context.insert(importRecord)

        // Fetch all existing transactions once for duplicate checking.
        let descriptor = FetchDescriptor<Transaction>()
        let existingTransactions = try context.fetch(descriptor)
        let accountID = account.id

        var knownFingerprints = Set(existingTransactions.compactMap { existing in
            fingerprint(for: existing, account: account, accountID: accountID)
        })

        var importedCount = 0
        var skippedDuplicates = 0
        var errors: [ImportRowError] = []

        for row in rows {
            // 1. Parse date.
            guard let dateString = row.values[mapping.dateColumn],
                  let date = DateParser.parse(dateString) else {
                let rawValue = row.values[mapping.dateColumn] ?? "<missing column>"
                errors.append(ImportRowError(
                    lineNumber: row.lineNumber,
                    message: "Could not parse date: \"\(rawValue)\""
                ))
                continue
            }

            // 2. Parse payee.
            let rawPayee = row.values[mapping.payeeColumn] ?? ""
            let payee = rawPayee.trimmingCharacters(in: .whitespaces).isEmpty ? "Unknown" : rawPayee.trimmingCharacters(in: .whitespaces)

            // 3. Parse amount (signed).
            guard let signedAmount = extractAmount(from: row, mapping: mapping) else {
                errors.append(ImportRowError(
                    lineNumber: row.lineNumber,
                    message: "Could not parse amount on row \(row.lineNumber)"
                ))
                continue
            }

            // 4. Parse optional memo.
            let memo: String?
            if let memoColumn = mapping.memoColumn {
                let raw = row.values[memoColumn]?.trimmingCharacters(in: .whitespaces) ?? ""
                memo = raw.isEmpty ? nil : raw
            } else {
                memo = nil
            }

            // 5. Absolute amount for entries (always positive).
            let absAmount = abs(signedAmount)

            // 6. Determine debit/credit sides based on account type and sign.
            // Positive amount for asset = money coming in (debit asset, credit contra).
            // Negative amount for asset = money going out (credit asset, debit contra).
            // Positive amount for liability = balance growing (credit liability, debit contra).
            // Negative amount for liability = payment (debit liability, credit contra).
            let (accountEntryType, contraEntryType) = entryTypes(
                for: account,
                signedAmount: signedAmount
            )

            // 7. Duplicate detection uses a stable fingerprint that includes sign semantics.
            let fingerprint = fingerprint(
                date: date,
                payee: payee,
                accountID: accountID,
                signedAmount: signedAmount
            )
            let isDuplicate = knownFingerprints.contains(fingerprint)

            if isDuplicate {
                skippedDuplicates += 1
                continue
            }

            // 8. Create transaction and entries directly.
            let transaction = Transaction(date: date, payee: payee, notes: memo, importRecord: importRecord)
            context.insert(transaction)

            let accountEntry = Entry(account: account, amount: absAmount, type: accountEntryType, memo: memo)
            context.insert(accountEntry)
            accountEntry.transaction = transaction
            transaction.entries.append(accountEntry)

            let contraEntry = Entry(account: contraAccount, amount: absAmount, type: contraEntryType)
            context.insert(contraEntry)
            contraEntry.transaction = transaction
            transaction.entries.append(contraEntry)

            importRecord.transactions.append(transaction)

            importedCount += 1
            knownFingerprints.insert(fingerprint)
        }

        return ImportResult(
            importRecord: importRecord,
            importedCount: importedCount,
            skippedDuplicates: skippedDuplicates,
            errors: errors
        )
    }

    // MARK: - Private helpers

    /// Extract the signed amount from a CSV row using the mapping.
    private func extractAmount(from row: CSVRow, mapping: ColumnMapping) -> Decimal? {
        if let amountColumn = mapping.amountColumn {
            guard let raw = row.values[amountColumn] else { return nil }
            return AmountParser.parse(raw)
        }

        // Separate debit / credit columns.
        if let debitColumn = mapping.debitColumn, let creditColumn = mapping.creditColumn {
            let debitRaw = row.values[debitColumn]?.trimmingCharacters(in: .whitespaces) ?? ""
            let creditRaw = row.values[creditColumn]?.trimmingCharacters(in: .whitespaces) ?? ""

            if !debitRaw.isEmpty, let amount = AmountParser.parse(debitRaw), amount != 0 {
                // Debit column: treat as negative (outflow from the account's perspective)
                return -abs(amount)
            }
            if !creditRaw.isEmpty, let amount = AmountParser.parse(creditRaw), amount != 0 {
                // Credit column: treat as positive (inflow to the account's perspective)
                return abs(amount)
            }

            return nil
        }

        return nil
    }

    private func fingerprint(
        date: Date,
        payee: String,
        accountID: UUID,
        signedAmount: Decimal
    ) -> TransactionFingerprint {
        TransactionFingerprint(
            date: Self.fingerprintCalendar.startOfDay(for: date),
            normalizedPayee: payee.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            accountID: accountID,
            signedAmount: NSDecimalNumber(decimal: signedAmount).stringValue
        )
    }

    private func fingerprint(
        for transaction: Transaction,
        account: Account,
        accountID: UUID
    ) -> TransactionFingerprint? {
        guard let accountEntry = transaction.entries.first(where: { $0.account?.id == accountID }) else {
            return nil
        }
        guard let accountEntryType = EntryType(rawValue: accountEntry.entryType) else {
            return nil
        }

        let signedAmount: Decimal
        if account.type.isDebitNormal {
            signedAmount = accountEntryType == .debit ? accountEntry.amount : -accountEntry.amount
        } else {
            signedAmount = accountEntryType == .credit ? accountEntry.amount : -accountEntry.amount
        }

        return fingerprint(
            date: transaction.date,
            payee: transaction.payee,
            accountID: accountID,
            signedAmount: signedAmount
        )
    }

    /// Determine the EntryType for the primary account and contra account based on
    /// account type and sign of the amount.
    ///
    /// For asset accounts (debit-normal):
    ///   Positive (inflow)  → debit asset,    credit contra
    ///   Negative (outflow) → credit asset,   debit contra
    ///
    /// For liability accounts (credit-normal):
    ///   Positive (balance grows) → credit liability, debit contra
    ///   Negative (payment)       → debit liability,  credit contra
    private func entryTypes(
        for account: Account,
        signedAmount: Decimal
    ) -> (accountEntryType: EntryType, contraEntryType: EntryType) {
        let isPositive = signedAmount >= 0

        if account.type.isDebitNormal {
            // Asset / expense: positive = increase = debit
            if isPositive {
                return (.debit, .credit)
            } else {
                return (.credit, .debit)
            }
        } else {
            // Liability / equity / income: positive = increase = credit
            if isPositive {
                return (.credit, .debit)
            } else {
                return (.debit, .credit)
            }
        }
    }
}

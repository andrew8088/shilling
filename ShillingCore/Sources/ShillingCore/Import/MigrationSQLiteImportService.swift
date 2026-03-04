import Foundation
import SQLite3
import SwiftData

public struct MigrationSQLiteImportCounts: Equatable, Sendable {
    public let accounts: Int
    public let importRecords: Int
    public let transactions: Int
    public let entries: Int
    public let budgets: Int

    public init(
        accounts: Int,
        importRecords: Int,
        transactions: Int,
        entries: Int,
        budgets: Int
    ) {
        self.accounts = accounts
        self.importRecords = importRecords
        self.transactions = transactions
        self.entries = entries
        self.budgets = budgets
    }
}

public struct MigrationSQLiteImportResult: Equatable, Sendable {
    public let sourceCounts: MigrationSQLiteImportCounts
    public let importedCounts: MigrationSQLiteImportCounts

    public init(sourceCounts: MigrationSQLiteImportCounts, importedCounts: MigrationSQLiteImportCounts) {
        self.sourceCounts = sourceCounts
        self.importedCounts = importedCounts
    }
}

public enum MigrationSQLiteImportError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidSQLite(message: String)
    case invalidRow(table: String, reason: String)
    case invariantViolation(String)
    case destinationNotEmpty(entity: String, count: Int)
    case persistenceMismatch(expected: MigrationSQLiteImportCounts, actual: MigrationSQLiteImportCounts)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Migration SQLite file not found: \(path)"
        case .invalidSQLite(let message):
            return "Invalid migration SQLite input: \(message)"
        case .invalidRow(let table, let reason):
            return "Invalid row in \(table): \(reason)"
        case .invariantViolation(let message):
            return "Migration invariant violation: \(message)"
        case .destinationNotEmpty(let entity, let count):
            return "Destination store is not empty (\(entity): \(count)). Use an empty data store for migration import."
        case .persistenceMismatch(let expected, let actual):
            return """
            Imported row counts do not match expected counts.
            Expected: accounts=\(expected.accounts), importRecords=\(expected.importRecords), transactions=\(expected.transactions), entries=\(expected.entries), budgets=\(expected.budgets)
            Actual: accounts=\(actual.accounts), importRecords=\(actual.importRecords), transactions=\(actual.transactions), entries=\(actual.entries), budgets=\(actual.budgets)
            """
        }
    }
}

public struct MigrationSQLiteImportService {
    private let context: ModelContext
    private let decimalLocale = Locale(identifier: "en_US_POSIX")

    public init(context: ModelContext) {
        self.context = context
    }

    public func importMigrationSQLite(at url: URL) throws -> MigrationSQLiteImportResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MigrationSQLiteImportError.fileNotFound(url.path)
        }

        try ensureDestinationIsEmpty()

        let reader = try SQLiteReader(url: url, service: self)
        let sourceCounts = try reader.loadCounts()
        let sourceAccounts = try reader.loadAccounts()
        let sourceImportRecords = try reader.loadImportRecords()
        let sourceTransactions = try reader.loadTransactions()
        let sourceEntries = try reader.loadEntries()
        let sourceBudgets = try reader.loadBudgets()

        try validateSourceInvariants(
            accounts: sourceAccounts,
            importRecords: sourceImportRecords,
            transactions: sourceTransactions,
            entries: sourceEntries,
            budgets: sourceBudgets
        )

        var accountsByID: [UUID: Account] = [:]
        var importRecordsByID: [UUID: ImportRecord] = [:]
        var transactionsByID: [UUID: Transaction] = [:]

        for source in sourceAccounts {
            let account = Account(
                name: source.name,
                type: source.accountType,
                parent: nil,
                isArchived: source.isArchived,
                notes: source.notes
            )
            account.id = source.id
            if let createdAt = source.createdAt {
                account.createdAt = createdAt
            }
            context.insert(account)
            accountsByID[source.id] = account
        }

        for source in sourceImportRecords {
            let importRecord = ImportRecord(fileName: source.fileName, rowCount: source.rowCount)
            importRecord.id = source.id
            importRecord.importedAt = source.importedAt
            context.insert(importRecord)
            importRecordsByID[source.id] = importRecord
        }

        for source in sourceTransactions {
            let importRecord = source.importRecordID.flatMap { importRecordsByID[$0] }
            let transaction = Transaction(
                date: source.date,
                payee: source.payee,
                notes: source.notes,
                importRecord: importRecord
            )
            transaction.id = source.id
            if let createdAt = source.createdAt {
                transaction.createdAt = createdAt
            }
            context.insert(transaction)
            if let importRecord {
                importRecord.transactions.append(transaction)
            }
            transactionsByID[source.id] = transaction
        }

        for source in sourceEntries {
            guard let account = accountsByID[source.accountID] else {
                throw MigrationSQLiteImportError.invariantViolation(
                    "target_entries row \(source.id.uuidString) references missing account \(source.accountID.uuidString)"
                )
            }
            guard let transaction = transactionsByID[source.transactionID] else {
                throw MigrationSQLiteImportError.invariantViolation(
                    "target_entries row \(source.id.uuidString) references missing transaction \(source.transactionID.uuidString)"
                )
            }

            let entry = Entry(account: account, amount: source.amount, type: source.entryType, memo: source.memo)
            entry.id = source.id
            context.insert(entry)
            entry.transaction = transaction
            transaction.entries.append(entry)
        }

        for source in sourceBudgets {
            guard let account = accountsByID[source.accountID] else {
                throw MigrationSQLiteImportError.invariantViolation(
                    "target_budgets row \(source.id.uuidString) references missing account \(source.accountID.uuidString)"
                )
            }
            let budget = Budget(
                account: account,
                year: source.year,
                month: source.month,
                amount: source.amount
            )
            budget.id = source.id
            context.insert(budget)
        }

        try context.save()

        let importedCounts = try persistedCounts()
        guard importedCounts == sourceCounts else {
            throw MigrationSQLiteImportError.persistenceMismatch(expected: sourceCounts, actual: importedCounts)
        }

        return MigrationSQLiteImportResult(
            sourceCounts: sourceCounts,
            importedCounts: importedCounts
        )
    }

    private func ensureDestinationIsEmpty() throws {
        let accountCount = try context.fetch(FetchDescriptor<Account>()).count
        if accountCount > 0 {
            throw MigrationSQLiteImportError.destinationNotEmpty(entity: "Account", count: accountCount)
        }

        let transactionCount = try context.fetch(FetchDescriptor<Transaction>()).count
        if transactionCount > 0 {
            throw MigrationSQLiteImportError.destinationNotEmpty(entity: "Transaction", count: transactionCount)
        }

        let entryCount = try context.fetch(FetchDescriptor<Entry>()).count
        if entryCount > 0 {
            throw MigrationSQLiteImportError.destinationNotEmpty(entity: "Entry", count: entryCount)
        }

        let budgetCount = try context.fetch(FetchDescriptor<Budget>()).count
        if budgetCount > 0 {
            throw MigrationSQLiteImportError.destinationNotEmpty(entity: "Budget", count: budgetCount)
        }

        let importRecordCount = try context.fetch(FetchDescriptor<ImportRecord>()).count
        if importRecordCount > 0 {
            throw MigrationSQLiteImportError.destinationNotEmpty(entity: "ImportRecord", count: importRecordCount)
        }
    }

    private func persistedCounts() throws -> MigrationSQLiteImportCounts {
        MigrationSQLiteImportCounts(
            accounts: try context.fetch(FetchDescriptor<Account>()).count,
            importRecords: try context.fetch(FetchDescriptor<ImportRecord>()).count,
            transactions: try context.fetch(FetchDescriptor<Transaction>()).count,
            entries: try context.fetch(FetchDescriptor<Entry>()).count,
            budgets: try context.fetch(FetchDescriptor<Budget>()).count
        )
    }

    private func validateSourceInvariants(
        accounts: [SourceAccountRow],
        importRecords: [SourceImportRecordRow],
        transactions: [SourceTransactionRow],
        entries: [SourceEntryRow],
        budgets: [SourceBudgetRow]
    ) throws {
        let accountByID = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        let importRecordIDs = Set(importRecords.map(\.id))
        let transactionIDs = Set(transactions.map(\.id))

        for transaction in transactions {
            if let importRecordID = transaction.importRecordID, !importRecordIDs.contains(importRecordID) {
                throw MigrationSQLiteImportError.invariantViolation(
                    "target_transactions row \(transaction.id.uuidString) references missing import record \(importRecordID.uuidString)"
                )
            }
        }

        var entriesByTransactionID: [UUID: [SourceEntryRow]] = [:]
        for entry in entries {
            guard accountByID[entry.accountID] != nil else {
                throw MigrationSQLiteImportError.invariantViolation(
                    "target_entries row \(entry.id.uuidString) references missing account \(entry.accountID.uuidString)"
                )
            }
            guard transactionIDs.contains(entry.transactionID) else {
                throw MigrationSQLiteImportError.invariantViolation(
                    "target_entries row \(entry.id.uuidString) references missing transaction \(entry.transactionID.uuidString)"
                )
            }
            entriesByTransactionID[entry.transactionID, default: []].append(entry)
        }

        for transaction in transactions {
            let groupedEntries = entriesByTransactionID[transaction.id] ?? []
            if groupedEntries.count != 2 {
                throw MigrationSQLiteImportError.invariantViolation(
                    "transaction \(transaction.id.uuidString) does not have exactly 2 entries (found \(groupedEntries.count))"
                )
            }

            let debitCount = groupedEntries.filter { $0.entryType == .debit }.count
            let creditCount = groupedEntries.filter { $0.entryType == .credit }.count
            if debitCount != 1 || creditCount != 1 {
                throw MigrationSQLiteImportError.invariantViolation(
                    "transaction \(transaction.id.uuidString) does not have one debit and one credit"
                )
            }

            let debitTotal = groupedEntries
                .filter { $0.entryType == .debit }
                .reduce(Decimal.zero) { $0 + $1.amount }
            let creditTotal = groupedEntries
                .filter { $0.entryType == .credit }
                .reduce(Decimal.zero) { $0 + $1.amount }
            if debitTotal != creditTotal {
                throw MigrationSQLiteImportError.invariantViolation(
                    "transaction \(transaction.id.uuidString) is not balanced (debits \(debitTotal), credits \(creditTotal))"
                )
            }
        }

        for budget in budgets {
            guard let account = accountByID[budget.accountID] else {
                throw MigrationSQLiteImportError.invariantViolation(
                    "target_budgets row \(budget.id.uuidString) references missing account \(budget.accountID.uuidString)"
                )
            }
            if account.accountType != .expense {
                throw MigrationSQLiteImportError.invariantViolation(
                    "target_budgets row \(budget.id.uuidString) references non-expense account \(budget.accountID.uuidString)"
                )
            }
        }
    }

    private func parseUUID(
        _ rawValue: String,
        table: String,
        column: String,
        rowID: String?
    ) throws -> UUID {
        guard let uuid = UUID(uuidString: rawValue) else {
            throw invalidRow(
                table: table,
                rowID: rowID,
                reason: "column \(column) has invalid UUID '\(rawValue)'"
            )
        }
        return uuid
    }

    private func parseRequiredDate(
        _ rawValue: String,
        table: String,
        column: String,
        rowID: String?
    ) throws -> Date {
        if let date = DateParser.parse(rawValue) {
            return date
        }
        if let date = Self.timestampFormatter.date(from: rawValue) {
            return date
        }
        if let date = Self.timestampFractional6Formatter.date(from: rawValue) {
            return date
        }
        if let date = Self.timestampFractional3Formatter.date(from: rawValue) {
            return date
        }
        if let date = Self.isoWithoutTimezoneFormatter.date(from: rawValue) {
            return date
        }
        if let date = Self.iso8601Formatter.date(from: rawValue) {
            return date
        }
        if let date = Self.iso8601FractionalFormatter.date(from: rawValue) {
            return date
        }

        throw invalidRow(
            table: table,
            rowID: rowID,
            reason: "column \(column) has invalid date '\(rawValue)'"
        )
    }

    private func parseOptionalDate(
        _ rawValue: String?,
        table: String,
        column: String,
        rowID: String?
    ) throws -> Date? {
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }
        return try parseRequiredDate(rawValue, table: table, column: column, rowID: rowID)
    }

    private func parseDecimal(
        _ rawValue: String,
        table: String,
        column: String,
        rowID: String?,
        allowZero: Bool
    ) throws -> Decimal {
        guard let decimal = Decimal(string: rawValue, locale: decimalLocale) else {
            throw invalidRow(
                table: table,
                rowID: rowID,
                reason: "column \(column) has invalid decimal '\(rawValue)'"
            )
        }

        if allowZero {
            if decimal < .zero {
                throw invalidRow(
                    table: table,
                    rowID: rowID,
                    reason: "column \(column) must be >= 0"
                )
            }
        } else if decimal <= .zero {
            throw invalidRow(
                table: table,
                rowID: rowID,
                reason: "column \(column) must be > 0"
            )
        }

        return decimal
    }

    private func invalidRow(table: String, rowID: String?, reason: String) -> MigrationSQLiteImportError {
        if let rowID {
            return .invalidRow(table: table, reason: "id \(rowID): \(reason)")
        }
        return .invalidRow(table: table, reason: reason)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let timestampFractional6Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
        return formatter
    }()

    private static let timestampFractional3Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private static let isoWithoutTimezoneFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let iso8601FractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

private extension MigrationSQLiteImportService {
    struct SourceAccountRow {
        let id: UUID
        let name: String
        let accountType: AccountType
        let isArchived: Bool
        let notes: String?
        let createdAt: Date?
    }

    struct SourceImportRecordRow {
        let id: UUID
        let fileName: String
        let importedAt: Date
        let rowCount: Int
    }

    struct SourceTransactionRow {
        let id: UUID
        let date: Date
        let payee: String
        let notes: String?
        let importRecordID: UUID?
        let createdAt: Date?
    }

    struct SourceEntryRow {
        let id: UUID
        let transactionID: UUID
        let accountID: UUID
        let amount: Decimal
        let entryType: EntryType
        let memo: String?
    }

    struct SourceBudgetRow {
        let id: UUID
        let accountID: UUID
        let year: Int
        let month: Int
        let amount: Decimal
    }
}

private extension MigrationSQLiteImportService {
    final class SQLiteReader {
        private typealias SQLiteRow = [String: String?]

        private let service: MigrationSQLiteImportService
        private var handle: OpaquePointer?

        init(url: URL, service: MigrationSQLiteImportService) throws {
            self.service = service
            var handle: OpaquePointer?
            let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
            let openCode = sqlite3_open_v2(url.path, &handle, flags, nil)
            guard openCode == SQLITE_OK else {
                let message = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown sqlite open failure"
                if handle != nil {
                    sqlite3_close(handle)
                }
                throw MigrationSQLiteImportError.invalidSQLite(message: message)
            }
            self.handle = handle
        }

        deinit {
            if let handle {
                sqlite3_close(handle)
            }
        }

        func loadCounts() throws -> MigrationSQLiteImportCounts {
            MigrationSQLiteImportCounts(
                accounts: try count("target_accounts"),
                importRecords: try count("target_import_records"),
                transactions: try count("target_transactions"),
                entries: try count("target_entries"),
                budgets: try count("target_budgets")
            )
        }

        func loadAccounts() throws -> [SourceAccountRow] {
            let rows = try query("""
            SELECT id, name, account_type, is_archived, notes, created_at
            FROM target_accounts
            ORDER BY id
            """)

            return try rows.map { row in
                let rowID = try requiredText(column: "id", in: row, table: "target_accounts", rowID: nil)
                let id = try service.parseUUID(rowID, table: "target_accounts", column: "id", rowID: rowID)
                let name = try requiredText(column: "name", in: row, table: "target_accounts", rowID: rowID)
                let rawType = try requiredText(column: "account_type", in: row, table: "target_accounts", rowID: rowID)
                guard let accountType = AccountType(rawValue: rawType) else {
                    throw service.invalidRow(
                        table: "target_accounts",
                        rowID: rowID,
                        reason: "unknown account_type '\(rawType)'"
                    )
                }
                let archivedRaw = try requiredText(column: "is_archived", in: row, table: "target_accounts", rowID: rowID)
                guard let archivedInt = Int(archivedRaw) else {
                    throw service.invalidRow(
                        table: "target_accounts",
                        rowID: rowID,
                        reason: "is_archived is not an integer"
                    )
                }
                return SourceAccountRow(
                    id: id,
                    name: name,
                    accountType: accountType,
                    isArchived: archivedInt != 0,
                    notes: optionalText(column: "notes", in: row),
                    createdAt: try service.parseOptionalDate(
                        optionalText(column: "created_at", in: row),
                        table: "target_accounts",
                        column: "created_at",
                        rowID: rowID
                    )
                )
            }
        }

        func loadImportRecords() throws -> [SourceImportRecordRow] {
            let rows = try query("""
            SELECT id, file_name, imported_at, row_count
            FROM target_import_records
            ORDER BY id
            """)

            return try rows.map { row in
                let rowID = try requiredText(column: "id", in: row, table: "target_import_records", rowID: nil)
                let id = try service.parseUUID(rowID, table: "target_import_records", column: "id", rowID: rowID)
                let fileName = try requiredText(column: "file_name", in: row, table: "target_import_records", rowID: rowID)
                let importedAtRaw = try requiredText(column: "imported_at", in: row, table: "target_import_records", rowID: rowID)
                let importedAt = try service.parseRequiredDate(
                    importedAtRaw,
                    table: "target_import_records",
                    column: "imported_at",
                    rowID: rowID
                )
                let rowCountRaw = try requiredText(column: "row_count", in: row, table: "target_import_records", rowID: rowID)
                guard let rowCount = Int(rowCountRaw), rowCount >= 0 else {
                    throw service.invalidRow(
                        table: "target_import_records",
                        rowID: rowID,
                        reason: "row_count must be >= 0"
                    )
                }

                return SourceImportRecordRow(
                    id: id,
                    fileName: fileName,
                    importedAt: importedAt,
                    rowCount: rowCount
                )
            }
        }

        func loadTransactions() throws -> [SourceTransactionRow] {
            let rows = try query("""
            SELECT id, date, payee, notes, import_record_id, created_at
            FROM target_transactions
            ORDER BY date, id
            """)

            return try rows.map { row in
                let rowID = try requiredText(column: "id", in: row, table: "target_transactions", rowID: nil)
                let id = try service.parseUUID(rowID, table: "target_transactions", column: "id", rowID: rowID)
                let dateRaw = try requiredText(column: "date", in: row, table: "target_transactions", rowID: rowID)
                let date = try service.parseRequiredDate(
                    dateRaw,
                    table: "target_transactions",
                    column: "date",
                    rowID: rowID
                )
                let payee = try requiredText(column: "payee", in: row, table: "target_transactions", rowID: rowID)
                let importRecordID: UUID?
                if let rawImportRecordID = optionalText(column: "import_record_id", in: row) {
                    importRecordID = try service.parseUUID(
                        rawImportRecordID,
                        table: "target_transactions",
                        column: "import_record_id",
                        rowID: rowID
                    )
                } else {
                    importRecordID = nil
                }

                return SourceTransactionRow(
                    id: id,
                    date: date,
                    payee: payee,
                    notes: optionalText(column: "notes", in: row),
                    importRecordID: importRecordID,
                    createdAt: try service.parseOptionalDate(
                        optionalText(column: "created_at", in: row),
                        table: "target_transactions",
                        column: "created_at",
                        rowID: rowID
                    )
                )
            }
        }

        func loadEntries() throws -> [SourceEntryRow] {
            let rows = try query("""
            SELECT id, transaction_id, account_id, amount, entry_type, memo
            FROM target_entries
            ORDER BY transaction_id, id
            """)

            return try rows.map { row in
                let rowID = try requiredText(column: "id", in: row, table: "target_entries", rowID: nil)
                let id = try service.parseUUID(rowID, table: "target_entries", column: "id", rowID: rowID)
                let transactionIDRaw = try requiredText(
                    column: "transaction_id",
                    in: row,
                    table: "target_entries",
                    rowID: rowID
                )
                let transactionID = try service.parseUUID(
                    transactionIDRaw,
                    table: "target_entries",
                    column: "transaction_id",
                    rowID: rowID
                )
                let accountIDRaw = try requiredText(
                    column: "account_id",
                    in: row,
                    table: "target_entries",
                    rowID: rowID
                )
                let accountID = try service.parseUUID(
                    accountIDRaw,
                    table: "target_entries",
                    column: "account_id",
                    rowID: rowID
                )
                let amountRaw = try requiredText(column: "amount", in: row, table: "target_entries", rowID: rowID)
                let amount = try service.parseDecimal(
                    amountRaw,
                    table: "target_entries",
                    column: "amount",
                    rowID: rowID,
                    allowZero: false
                )
                let rawEntryType = try requiredText(
                    column: "entry_type",
                    in: row,
                    table: "target_entries",
                    rowID: rowID
                )
                guard let entryType = EntryType(rawValue: rawEntryType) else {
                    throw service.invalidRow(
                        table: "target_entries",
                        rowID: rowID,
                        reason: "unknown entry_type '\(rawEntryType)'"
                    )
                }

                return SourceEntryRow(
                    id: id,
                    transactionID: transactionID,
                    accountID: accountID,
                    amount: amount,
                    entryType: entryType,
                    memo: optionalText(column: "memo", in: row)
                )
            }
        }

        func loadBudgets() throws -> [SourceBudgetRow] {
            let rows = try query("""
            SELECT id, account_id, year, month, amount
            FROM target_budgets
            ORDER BY year, month, id
            """)

            return try rows.map { row in
                let rowID = try requiredText(column: "id", in: row, table: "target_budgets", rowID: nil)
                let id = try service.parseUUID(rowID, table: "target_budgets", column: "id", rowID: rowID)
                let accountIDRaw = try requiredText(
                    column: "account_id",
                    in: row,
                    table: "target_budgets",
                    rowID: rowID
                )
                let accountID = try service.parseUUID(
                    accountIDRaw,
                    table: "target_budgets",
                    column: "account_id",
                    rowID: rowID
                )
                let yearRaw = try requiredText(column: "year", in: row, table: "target_budgets", rowID: rowID)
                let monthRaw = try requiredText(column: "month", in: row, table: "target_budgets", rowID: rowID)
                guard let year = Int(yearRaw), year > 0 else {
                    throw service.invalidRow(
                        table: "target_budgets",
                        rowID: rowID,
                        reason: "year must be > 0"
                    )
                }
                guard let month = Int(monthRaw), (1...12).contains(month) else {
                    throw service.invalidRow(
                        table: "target_budgets",
                        rowID: rowID,
                        reason: "month must be in 1...12"
                    )
                }
                let amountRaw = try requiredText(column: "amount", in: row, table: "target_budgets", rowID: rowID)
                let amount = try service.parseDecimal(
                    amountRaw,
                    table: "target_budgets",
                    column: "amount",
                    rowID: rowID,
                    allowZero: true
                )

                return SourceBudgetRow(
                    id: id,
                    accountID: accountID,
                    year: year,
                    month: month,
                    amount: amount
                )
            }
        }

        private func count(_ table: String) throws -> Int {
            let rows = try query("SELECT COUNT(*) AS n FROM \(table)")
            guard
                let value = rows.first?["n"] ?? nil,
                let count = Int(value)
            else {
                throw MigrationSQLiteImportError.invalidSQLite(
                    message: "Could not parse count from \(table)"
                )
            }
            return count
        }

        private func query(_ sql: String) throws -> [SQLiteRow] {
            guard let handle else {
                throw MigrationSQLiteImportError.invalidSQLite(message: "SQLite connection was not initialized")
            }

            var statement: OpaquePointer?
            let prepareCode = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
            guard prepareCode == SQLITE_OK else {
                throw sqliteError(for: handle, operation: "prepare", sql: sql)
            }
            defer { sqlite3_finalize(statement) }

            let columnCount = Int(sqlite3_column_count(statement))
            var rows: [SQLiteRow] = []

            while true {
                let stepCode = sqlite3_step(statement)
                if stepCode == SQLITE_ROW {
                    var row: SQLiteRow = [:]
                    row.reserveCapacity(columnCount)
                    for index in 0..<columnCount {
                        guard let namePtr = sqlite3_column_name(statement, Int32(index)) else {
                            continue
                        }
                        let name = String(cString: namePtr)
                        if sqlite3_column_type(statement, Int32(index)) == SQLITE_NULL {
                            row[name] = nil
                        } else if let valuePtr = sqlite3_column_text(statement, Int32(index)) {
                            row[name] = String(cString: valuePtr)
                        } else {
                            row[name] = nil
                        }
                    }
                    rows.append(row)
                    continue
                }
                if stepCode == SQLITE_DONE {
                    break
                }
                throw sqliteError(for: handle, operation: "step", sql: sql)
            }

            return rows
        }

        private func requiredText(
            column: String,
            in row: SQLiteRow,
            table: String,
            rowID: String?
        ) throws -> String {
            guard let value = row[column] ?? nil else {
                throw service.invalidRow(
                    table: table,
                    rowID: rowID,
                    reason: "missing required column \(column)"
                )
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                throw service.invalidRow(
                    table: table,
                    rowID: rowID,
                    reason: "column \(column) cannot be empty"
                )
            }
            return trimmed
        }

        private func optionalText(column: String, in row: SQLiteRow) -> String? {
            guard let value = row[column] ?? nil else {
                return nil
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        private func sqliteError(
            for handle: OpaquePointer,
            operation: String,
            sql: String
        ) -> MigrationSQLiteImportError {
            let message = String(cString: sqlite3_errmsg(handle))
            return .invalidSQLite(message: "\(operation) failed for query '\(sql)': \(message)")
        }
    }
}

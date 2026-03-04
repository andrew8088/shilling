import Foundation
import SQLite3
import SwiftData
import Testing
@testable import ShillingCore

@Suite("MigrationSQLiteImportService")
struct MigrationSQLiteImportServiceTests {
    private enum FixtureIDs {
        static let assetAccount = "11111111-1111-1111-1111-111111111111"
        static let expenseAccount = "22222222-2222-2222-2222-222222222222"
        static let equityAccount = "33333333-3333-3333-3333-333333333333"
        static let importRecord = "44444444-4444-4444-4444-444444444444"
        static let transactionA = "55555555-5555-5555-5555-555555555555"
        static let transactionB = "99999999-9999-9999-9999-999999999999"
        static let entryA1 = "66666666-6666-6666-6666-666666666666"
        static let entryA2 = "77777777-7777-7777-7777-777777777777"
        static let entryB1 = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        static let entryB2 = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        static let budget = "88888888-8888-8888-8888-888888888888"
    }

    @MainActor
    private func makeService() throws -> (ModelContext, MigrationSQLiteImportService) {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = MigrationSQLiteImportService(context: context)
        return (context, service)
    }

    private func makeSQLiteURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-import-\(UUID().uuidString).sqlite")
    }

    private func writeFixtureDatabase(
        at url: URL,
        additionalStatements: [String] = []
    ) throws {
        _ = try? FileManager.default.removeItem(at: url)

        var db: OpaquePointer?
        guard sqlite3_open_v2(
            url.path,
            &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK else {
            defer { sqlite3_close(db) }
            throw FixtureSQLiteError.openFailed(message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_close(db) }

        try execute(db, sql: """
        CREATE TABLE target_accounts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            account_type TEXT NOT NULL,
            is_archived INTEGER NOT NULL,
            notes TEXT,
            created_at TEXT,
            source_kind TEXT NOT NULL,
            source_id TEXT
        );

        CREATE TABLE target_import_records (
            id TEXT PRIMARY KEY,
            file_name TEXT NOT NULL,
            imported_at TEXT NOT NULL,
            row_count INTEGER NOT NULL,
            source_import_id TEXT NOT NULL,
            source_status TEXT
        );

        CREATE TABLE target_transactions (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            payee TEXT NOT NULL,
            notes TEXT,
            import_record_id TEXT,
            created_at TEXT,
            source_mode TEXT NOT NULL,
            source_transaction_ids TEXT NOT NULL,
            source_transfer_status TEXT
        );

        CREATE TABLE target_entries (
            id TEXT PRIMARY KEY,
            transaction_id TEXT NOT NULL,
            account_id TEXT NOT NULL,
            amount TEXT NOT NULL,
            entry_type TEXT NOT NULL,
            memo TEXT,
            source_entry_id TEXT
        );

        CREATE TABLE target_budgets (
            id TEXT PRIMARY KEY,
            account_id TEXT NOT NULL,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            amount TEXT NOT NULL,
            source_budget_category_id TEXT NOT NULL,
            currency TEXT
        );
        """)

        try execute(db, sql: """
        INSERT INTO target_accounts (id, name, account_type, is_archived, notes, created_at, source_kind, source_id)
        VALUES
            ('\(FixtureIDs.assetAccount)', 'Checking', 'asset', 0, '{"legacy":"account"}', '2026-01-01 09:00:00', 'account', 'src-a1'),
            ('\(FixtureIDs.expenseAccount)', 'Category: Groceries', 'expense', 0, '{"legacy":"category"}', '2026-01-01 09:00:00', 'category', 'src-c1'),
            ('\(FixtureIDs.equityAccount)', 'Legacy Import Suspense', 'equity', 0, '{"legacy":"system"}', '2026-01-01 09:00:00', 'system', 'legacy-import-suspense');
        """)

        try execute(db, sql: """
        INSERT INTO target_import_records (id, file_name, imported_at, row_count, source_import_id, source_status)
        VALUES
            ('\(FixtureIDs.importRecord)', 'legacy-import-\(FixtureIDs.importRecord).csv', '2026-01-10 10:00:00', 2, 'src-i1', 'processed');
        """)

        try execute(db, sql: """
        INSERT INTO target_transactions (id, date, payee, notes, import_record_id, created_at, source_mode, source_transaction_ids, source_transfer_status)
        VALUES
            ('\(FixtureIDs.transactionA)', '2026-01-15', 'Groceries', 'first tx', '\(FixtureIDs.importRecord)', '2026-01-15 12:00:00', 'single_transaction', 'src-tx-a', NULL),
            ('\(FixtureIDs.transactionB)', '2026-01-16', 'Salary', 'second tx', NULL, '2026-01-16 12:00:00', 'single_transaction', 'src-tx-b', NULL);
        """)

        try execute(db, sql: """
        INSERT INTO target_entries (id, transaction_id, account_id, amount, entry_type, memo, source_entry_id)
        VALUES
            ('\(FixtureIDs.entryA1)', '\(FixtureIDs.transactionA)', '\(FixtureIDs.expenseAccount)', '120.50', 'debit', 'groceries memo', 'src-e1'),
            ('\(FixtureIDs.entryA2)', '\(FixtureIDs.transactionA)', '\(FixtureIDs.assetAccount)', '120.50', 'credit', NULL, NULL),
            ('\(FixtureIDs.entryB1)', '\(FixtureIDs.transactionB)', '\(FixtureIDs.assetAccount)', '3000.00', 'debit', NULL, 'src-e2'),
            ('\(FixtureIDs.entryB2)', '\(FixtureIDs.transactionB)', '\(FixtureIDs.equityAccount)', '3000.00', 'credit', NULL, NULL);
        """)

        try execute(db, sql: """
        INSERT INTO target_budgets (id, account_id, year, month, amount, source_budget_category_id, currency)
        VALUES
            ('\(FixtureIDs.budget)', '\(FixtureIDs.expenseAccount)', 2026, 1, '500.00', 'src-bc1', 'CAD');
        """)

        for statement in additionalStatements {
            try execute(db, sql: statement)
        }
    }

    private func execute(_ db: OpaquePointer?, sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(db, sql, nil, nil, &errorPointer)
        if code == SQLITE_OK {
            return
        }

        let message: String
        if let errorPointer {
            message = String(cString: errorPointer)
            sqlite3_free(errorPointer)
        } else {
            message = "SQLite error code \(code)"
        }
        throw FixtureSQLiteError.statementFailed(message: message)
    }

    @Test @MainActor
    func importsMigrationSQLiteWithExpectedCountsAndBalances() throws {
        let (context, service) = try makeService()
        let fixtureURL = makeSQLiteURL()
        try writeFixtureDatabase(at: fixtureURL)

        let result = try service.importMigrationSQLite(at: fixtureURL)

        #expect(result.sourceCounts.accounts == 3)
        #expect(result.sourceCounts.importRecords == 1)
        #expect(result.sourceCounts.transactions == 2)
        #expect(result.sourceCounts.entries == 4)
        #expect(result.sourceCounts.budgets == 1)
        #expect(result.importedCounts == result.sourceCounts)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let entries = try context.fetch(FetchDescriptor<Entry>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let importRecords = try context.fetch(FetchDescriptor<ImportRecord>())

        #expect(accounts.count == 3)
        #expect(transactions.count == 2)
        #expect(entries.count == 4)
        #expect(budgets.count == 1)
        #expect(importRecords.count == 1)

        #expect(accounts.contains(where: { $0.id.uuidString == FixtureIDs.assetAccount }))
        #expect(accounts.contains(where: { $0.id.uuidString == FixtureIDs.expenseAccount }))
        #expect(transactions.contains(where: { $0.id.uuidString == FixtureIDs.transactionA }))
        #expect(transactions.contains(where: { $0.id.uuidString == FixtureIDs.transactionB }))

        for transaction in transactions {
            #expect(transaction.entries.count == 2)

            let debitTotal = transaction.entries
                .filter { $0.type == .debit }
                .reduce(Decimal.zero) { $0 + $1.amount }
            let creditTotal = transaction.entries
                .filter { $0.type == .credit }
                .reduce(Decimal.zero) { $0 + $1.amount }
            #expect(debitTotal == creditTotal)
        }
    }

    @Test @MainActor
    func failsFastOnMissingAccountReferenceInEntries() throws {
        let (context, service) = try makeService()
        let fixtureURL = makeSQLiteURL()
        try writeFixtureDatabase(
            at: fixtureURL,
            additionalStatements: [
                "UPDATE target_entries SET account_id='dddddddd-dddd-dddd-dddd-dddddddddddd' WHERE id='\(FixtureIDs.entryA1)';"
            ]
        )

        do {
            _ = try service.importMigrationSQLite(at: fixtureURL)
            Issue.record("Expected missing account reference to fail import.")
        } catch let error as MigrationSQLiteImportError {
            switch error {
            case .invariantViolation(let message):
                #expect(message.contains("missing account"))
            default:
                Issue.record("Unexpected importer error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(try context.fetch(FetchDescriptor<Account>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Transaction>()).isEmpty)
    }

    @Test @MainActor
    func failsFastOnEntryCardinalityViolation() throws {
        let (_, service) = try makeService()
        let fixtureURL = makeSQLiteURL()
        try writeFixtureDatabase(
            at: fixtureURL,
            additionalStatements: [
                "DELETE FROM target_entries WHERE id='\(FixtureIDs.entryB2)';"
            ]
        )

        do {
            _ = try service.importMigrationSQLite(at: fixtureURL)
            Issue.record("Expected entry cardinality violation to fail import.")
        } catch let error as MigrationSQLiteImportError {
            switch error {
            case .invariantViolation(let message):
                #expect(message.contains("exactly 2 entries"))
            default:
                Issue.record("Unexpected importer error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test @MainActor
    func failsFastOnUnbalancedEntries() throws {
        let (_, service) = try makeService()
        let fixtureURL = makeSQLiteURL()
        try writeFixtureDatabase(
            at: fixtureURL,
            additionalStatements: [
                "UPDATE target_entries SET amount='119.50' WHERE id='\(FixtureIDs.entryA2)';"
            ]
        )

        do {
            _ = try service.importMigrationSQLite(at: fixtureURL)
            Issue.record("Expected unbalanced entries to fail import.")
        } catch let error as MigrationSQLiteImportError {
            switch error {
            case .invariantViolation(let message):
                #expect(message.contains("not balanced"))
            default:
                Issue.record("Unexpected importer error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private enum FixtureSQLiteError: Error {
    case openFailed(message: String)
    case statementFailed(message: String)
}

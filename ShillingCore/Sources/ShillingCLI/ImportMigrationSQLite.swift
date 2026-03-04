import ArgumentParser
import Foundation
import ShillingCore
import SwiftData

struct ImportMigrationSQLite: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import-migration-sqlite",
        abstract: "Import target_* migration SQLite tables into Shilling data store"
    )

    @Option(name: .long, help: "Path to migration SQLite file produced by the legacy exporter")
    var input: String

    @Option(name: .long, help: "Target Shilling data directory path")
    var dataDir: String?

    func run() throws {
        let inputURL = URL(fileURLWithPath: input)
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw ValidationError("Input file not found: \(input)")
        }

        let container = try DataStore.makeContainer(dataDir: dataDir)
        let context = ModelContext(container)
        let service = MigrationSQLiteImportService(context: context)

        let result = try service.importMigrationSQLite(at: inputURL)

        print("Migration import complete.")
        print("Verification: PASS")
        print("Source rows:")
        print("  Accounts: \(result.sourceCounts.accounts)")
        print("  Import records: \(result.sourceCounts.importRecords)")
        print("  Transactions: \(result.sourceCounts.transactions)")
        print("  Entries: \(result.sourceCounts.entries)")
        print("  Budgets: \(result.sourceCounts.budgets)")
        print("Persisted rows:")
        print("  Accounts: \(result.importedCounts.accounts)")
        print("  Import records: \(result.importedCounts.importRecords)")
        print("  Transactions: \(result.importedCounts.transactions)")
        print("  Entries: \(result.importedCounts.entries)")
        print("  Budgets: \(result.importedCounts.budgets)")
    }
}

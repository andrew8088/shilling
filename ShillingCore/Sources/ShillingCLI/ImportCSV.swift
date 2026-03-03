import ArgumentParser
import Foundation
import ShillingCore
import SwiftData

struct ImportCSV: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import-csv",
        abstract: "Import transactions from a CSV file"
    )

    @Argument(help: "Path to the CSV file")
    var file: String

    @Option(name: .long, help: "Target account name (the account this statement belongs to)")
    var account: String

    @Option(name: .long, help: "Contra account name (default other side of transactions)")
    var contraAccount: String

    @Option(name: .long, help: "Column name for date")
    var dateCol: String

    @Option(name: .long, help: "Column name for payee/description")
    var payeeCol: String

    @Option(name: .long, help: "Column name for signed amount (mutually exclusive with --debit-col/--credit-col)")
    var amountCol: String?

    @Option(name: .long, help: "Column name for debit amounts")
    var debitCol: String?

    @Option(name: .long, help: "Column name for credit amounts")
    var creditCol: String?

    @Option(name: .long, help: "Column name for memo/notes (optional)")
    var memoCol: String?

    @Option(name: .long, help: "Custom data directory path")
    var dataDir: String?

    func validate() throws {
        if amountCol == nil && (debitCol == nil || creditCol == nil) {
            throw ValidationError("Provide either --amount-col or both --debit-col and --credit-col.")
        }
        if amountCol != nil && (debitCol != nil || creditCol != nil) {
            throw ValidationError("Cannot use --amount-col together with --debit-col/--credit-col.")
        }
    }

    func run() throws {
        let url = URL(fileURLWithPath: file)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("File not found: \(file)")
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        let parser = CSVParser()
        let rows = try parser.parse(content)

        let container = try DataStore.makeContainer(dataDir: dataDir)
        let context = ModelContext(container)

        // Find accounts by name
        let allAccounts = try context.fetch(FetchDescriptor<Account>())
        guard let targetAccount = allAccounts.first(where: { $0.name == account }) else {
            throw ValidationError("Account not found: \(account)")
        }
        guard let contraAcc = allAccounts.first(where: { $0.name == contraAccount }) else {
            throw ValidationError("Account not found: \(contraAccount)")
        }

        let mapping: ColumnMapping
        if let amountCol {
            mapping = ColumnMapping(
                dateColumn: dateCol,
                payeeColumn: payeeCol,
                amountColumn: amountCol,
                memoColumn: memoCol
            )
        } else {
            mapping = ColumnMapping(
                dateColumn: dateCol,
                payeeColumn: payeeCol,
                debitColumn: debitCol!,
                creditColumn: creditCol!,
                memoColumn: memoCol
            )
        }

        let service = ImportService(context: context)
        let result = try service.importRows(
            rows,
            mapping: mapping,
            account: targetAccount,
            contraAccount: contraAcc,
            fileName: url.lastPathComponent
        )
        try context.save()

        print("Import complete:")
        print("  Imported: \(result.importedCount)")
        print("  Duplicates skipped: \(result.skippedDuplicates)")
        if !result.errors.isEmpty {
            print("  Errors: \(result.errors.count)")
            for error in result.errors.prefix(10) {
                print("    Row \(error.lineNumber): \(error.message)")
            }
            if result.errors.count > 10 {
                print("    ... and \(result.errors.count - 10) more")
            }
        }
    }
}

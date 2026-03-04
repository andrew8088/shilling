import Foundation
import Testing
import SwiftData
@testable import ShillingCore

@Suite("ImportService")
struct ImportServiceTests {

    // MARK: - Helpers

    @MainActor
    private func makeService() throws -> (ModelContainer, ModelContext, ImportService) {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = ImportService(context: context)
        return (container, context, service)
    }

    /// A reusable standard ColumnMapping with a single signed amount column.
    private var signedAmountMapping: ColumnMapping {
        ColumnMapping(
            dateColumn: "Date",
            payeeColumn: "Payee",
            amountColumn: "Amount"
        )
    }

    /// A reusable ColumnMapping with separate debit/credit columns.
    private var debitCreditMapping: ColumnMapping {
        ColumnMapping(
            dateColumn: "Date",
            payeeColumn: "Payee",
            debitColumn: "Debit",
            creditColumn: "Credit"
        )
    }

    /// Build a CSVRow with the given field dictionary and line number.
    private func row(_ values: [String: String], line: Int = 1) -> CSVRow {
        CSVRow(values: values, lineNumber: line)
    }

    /// A fixed date for use in tests (2026-01-15 UTC).
    private var testDate: Date {
        // "2026-01-15" parsed via DateParser (ISO format)
        DateParser.parse("2026-01-15")!
    }

    // MARK: - 1. Basic import

    @Test @MainActor
    func basicImportCreatesTransactionsAndImportRecord() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let uncategorized = Account(name: "Uncategorized Expense", type: .expense)
        context.insert(chequing)
        context.insert(uncategorized)

        let rows = [
            row(["Date": "2026-01-15", "Payee": "Grocery Store", "Amount": "-55.00"], line: 2),
            row(["Date": "2026-01-16", "Payee": "Salary", "Amount": "2000.00"], line: 3),
            row(["Date": "2026-01-17", "Payee": "Coffee Shop", "Amount": "-4.50"], line: 4),
        ]

        let result = try service.importRows(
            rows,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: uncategorized,
            fileName: "bank.csv"
        )

        #expect(result.importedCount == 3)
        #expect(result.skippedDuplicates == 0)
        #expect(result.errors.isEmpty)
        #expect(result.importRecord.fileName == "bank.csv")
        #expect(result.importRecord.rowCount == 3)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)
        #expect(transactions.count == 3)
    }

    // MARK: - 2. Signed amounts: correct debit/credit direction for asset account

    @Test @MainActor
    func positiveAmountForAssetAccountDebitsAssetCreditsConta() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let income = Account(name: "Income", type: .income)
        context.insert(chequing)
        context.insert(income)

        let rows = [
            row(["Date": "2026-01-15", "Payee": "Salary", "Amount": "1000.00"]),
        ]

        let result = try service.importRows(
            rows,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: income,
            fileName: "bank.csv"
        )

        #expect(result.importedCount == 1)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)
        let tx = try #require(transactions.first)

        let chequingEntry = try #require(tx.entries.first(where: { $0.account?.id == chequing.id }))
        let contraEntry = try #require(tx.entries.first(where: { $0.account?.id == income.id }))

        #expect(chequingEntry.type == .debit)
        #expect(chequingEntry.amount == 1000.00)
        #expect(contraEntry.type == .credit)
        #expect(contraEntry.amount == 1000.00)
    }

    @Test @MainActor
    func negativeAmountForAssetAccountCreditsAssetDebitsContra() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let expense = Account(name: "Groceries", type: .expense)
        context.insert(chequing)
        context.insert(expense)

        let rows = [
            row(["Date": "2026-01-15", "Payee": "Grocery Store", "Amount": "-75.00"]),
        ]

        let result = try service.importRows(
            rows,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: expense,
            fileName: "bank.csv"
        )

        #expect(result.importedCount == 1)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)
        let tx = try #require(transactions.first)

        let chequingEntry = try #require(tx.entries.first(where: { $0.account?.id == chequing.id }))
        let contraEntry = try #require(tx.entries.first(where: { $0.account?.id == expense.id }))

        // Negative amount on asset: credit the asset, debit the contra
        #expect(chequingEntry.type == .credit)
        #expect(chequingEntry.amount == 75.00)
        #expect(contraEntry.type == .debit)
        #expect(contraEntry.amount == 75.00)
    }

    // MARK: - 3. Debit/credit columns

    @Test @MainActor
    func separateDebitCreditColumnsImportCorrectly() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let expense = Account(name: "Expenses", type: .expense)
        context.insert(chequing)
        context.insert(expense)

        // Debit column = outflow (negative sign), Credit column = inflow (positive sign)
        let rows = [
            row(["Date": "2026-01-15", "Payee": "Coffee", "Debit": "4.50", "Credit": ""], line: 2),
            row(["Date": "2026-01-16", "Payee": "Refund", "Debit": "", "Credit": "10.00"], line: 3),
        ]

        let result = try service.importRows(
            rows,
            mapping: debitCreditMapping,
            account: chequing,
            contraAccount: expense,
            fileName: "bank.csv"
        )

        #expect(result.importedCount == 2)
        #expect(result.errors.isEmpty)

        let txDescriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)])
        let transactions = try context.fetch(txDescriptor)
        #expect(transactions.count == 2)

        // Coffee row: debit column populated → negative signed amount → credit chequing, debit contra
        let coffeeTx = try #require(transactions.first(where: { $0.payee == "Coffee" }))
        let coffeeChequingEntry = try #require(coffeeTx.entries.first(where: { $0.account?.id == chequing.id }))
        #expect(coffeeChequingEntry.type == .credit)
        #expect(coffeeChequingEntry.amount == 4.50)

        // Refund row: credit column populated → positive signed amount → debit chequing, credit contra
        let refundTx = try #require(transactions.first(where: { $0.payee == "Refund" }))
        let refundChequingEntry = try #require(refundTx.entries.first(where: { $0.account?.id == chequing.id }))
        #expect(refundChequingEntry.type == .debit)
        #expect(refundChequingEntry.amount == 10.00)
    }

    // MARK: - 4. Duplicate detection — all rows skipped on second import

    @Test @MainActor
    func duplicateDetectionSkipsAllRowsOnSecondImport() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let expense = Account(name: "Expenses", type: .expense)
        context.insert(chequing)
        context.insert(expense)

        let rows = [
            row(["Date": "2026-01-15", "Payee": "Grocery Store", "Amount": "-55.00"], line: 2),
            row(["Date": "2026-01-16", "Payee": "Coffee Shop", "Amount": "-4.50"], line: 3),
        ]

        let result1 = try service.importRows(
            rows,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: expense,
            fileName: "bank.csv"
        )
        #expect(result1.importedCount == 2)
        #expect(result1.skippedDuplicates == 0)

        let result2 = try service.importRows(
            rows,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: expense,
            fileName: "bank.csv"
        )
        #expect(result2.importedCount == 0)
        #expect(result2.skippedDuplicates == 2)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)
        #expect(transactions.count == 2)
    }

    @Test @MainActor
    func duplicateDetectionWithinSameBatchSkipsSubsequentRows() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let expense = Account(name: "Expenses", type: .expense)
        context.insert(chequing)
        context.insert(expense)

        let rows = [
            row(["Date": "2026-01-15", "Payee": "Grocery Store", "Amount": "-55.00"], line: 2),
            row(["Date": "2026-01-15", "Payee": "Grocery Store", "Amount": "-55.00"], line: 3), // duplicate within same batch
        ]

        let result = try service.importRows(
            rows,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: expense,
            fileName: "bank.csv"
        )

        #expect(result.importedCount == 1)
        #expect(result.skippedDuplicates == 1)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)
        #expect(transactions.count == 1)
    }

    @Test @MainActor
    func duplicateDetectionTreatsOppositeSignedAmountsAsDistinctSemantics() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let expense = Account(name: "Expenses", type: .expense)
        context.insert(chequing)
        context.insert(expense)

        let purchaseRows = [
            row(["Date": "2026-01-15", "Payee": "Grocery Store", "Amount": "-55.00"], line: 2),
        ]
        let refundRows = [
            row(["Date": "2026-01-15", "Payee": "Grocery Store", "Amount": "55.00"], line: 2),
        ]

        let firstImport = try service.importRows(
            purchaseRows,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: expense,
            fileName: "purchase.csv"
        )
        #expect(firstImport.importedCount == 1)

        let secondImport = try service.importRows(
            refundRows,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: expense,
            fileName: "refund.csv"
        )
        #expect(secondImport.importedCount == 1)
        #expect(secondImport.skippedDuplicates == 0)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)
        #expect(transactions.count == 2)

        let chequingEntries = transactions.compactMap { transaction in
            transaction.entries.first(where: { $0.account?.id == chequing.id })
        }
        #expect(chequingEntries.count == 2)
        #expect(chequingEntries.contains(where: { $0.type == .credit && $0.amount == 55.00 }))
        #expect(chequingEntries.contains(where: { $0.type == .debit && $0.amount == 55.00 }))
    }

    // MARK: - 5. Partial duplicates

    @Test @MainActor
    func partialDuplicatesOnlySkipMatchingRows() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let expense = Account(name: "Expenses", type: .expense)
        context.insert(chequing)
        context.insert(expense)

        let firstBatch = [
            row(["Date": "2026-01-15", "Payee": "Grocery Store", "Amount": "-55.00"], line: 2),
        ]
        let result1 = try service.importRows(
            firstBatch,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: expense,
            fileName: "bank.csv"
        )
        #expect(result1.importedCount == 1)

        let secondBatch = [
            row(["Date": "2026-01-15", "Payee": "Grocery Store", "Amount": "-55.00"], line: 2), // duplicate
            row(["Date": "2026-01-16", "Payee": "New Payee", "Amount": "-10.00"], line: 3),      // new
        ]
        let result2 = try service.importRows(
            secondBatch,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: expense,
            fileName: "bank2.csv"
        )
        #expect(result2.importedCount == 1)
        #expect(result2.skippedDuplicates == 1)

        let txDescriptor = FetchDescriptor<Transaction>()
        let all = try context.fetch(txDescriptor)
        #expect(all.count == 2)
    }

    // MARK: - 6. Invalid date row

    @Test @MainActor
    func invalidDateRowProducesErrorAndIsSkipped() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let expense = Account(name: "Expenses", type: .expense)
        context.insert(chequing)
        context.insert(expense)

        let rows = [
            row(["Date": "not-a-date", "Payee": "Grocery Store", "Amount": "-55.00"], line: 2),
            row(["Date": "2026-01-16", "Payee": "Coffee Shop", "Amount": "-4.50"], line: 3),
        ]

        let result = try service.importRows(
            rows,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: expense,
            fileName: "bank.csv"
        )

        #expect(result.importedCount == 1)
        #expect(result.errors.count == 1)
        #expect(result.errors[0].lineNumber == 2)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)
        #expect(transactions.count == 1)
    }

    // MARK: - 7. Invalid amount row

    @Test @MainActor
    func invalidAmountRowProducesErrorAndIsSkipped() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let expense = Account(name: "Expenses", type: .expense)
        context.insert(chequing)
        context.insert(expense)

        let rows = [
            row(["Date": "2026-01-15", "Payee": "Grocery Store", "Amount": "not-an-amount"], line: 2),
            row(["Date": "2026-01-16", "Payee": "Coffee Shop", "Amount": "-4.50"], line: 3),
        ]

        let result = try service.importRows(
            rows,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: expense,
            fileName: "bank.csv"
        )

        #expect(result.importedCount == 1)
        #expect(result.errors.count == 1)
        #expect(result.errors[0].lineNumber == 2)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)
        #expect(transactions.count == 1)
    }

    // MARK: - 8. Empty payee defaults to "Unknown"

    @Test @MainActor
    func emptyPayeeDefaultsToUnknown() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let expense = Account(name: "Expenses", type: .expense)
        context.insert(chequing)
        context.insert(expense)

        let rows = [
            row(["Date": "2026-01-15", "Payee": "", "Amount": "-10.00"]),
        ]

        let result = try service.importRows(
            rows,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: expense,
            fileName: "bank.csv"
        )

        #expect(result.importedCount == 1)
        #expect(result.errors.isEmpty)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)
        let tx = try #require(transactions.first)
        #expect(tx.payee == "Unknown")
    }

    // MARK: - 9. Liability account: debit/credit direction is reversed

    @Test @MainActor
    func liabilityAccountPositiveAmountCreditLiabilityDebitContra() throws {
        let (_, context, service) = try makeService()

        let creditCard = Account(name: "Credit Card", type: .liability)
        let expense = Account(name: "Expenses", type: .expense)
        context.insert(creditCard)
        context.insert(expense)

        // Positive on liability = balance growing (a charge) → credit the liability
        let rows = [
            row(["Date": "2026-01-15", "Payee": "Restaurant", "Amount": "45.00"]),
        ]

        let result = try service.importRows(
            rows,
            mapping: signedAmountMapping,
            account: creditCard,
            contraAccount: expense,
            fileName: "cc.csv"
        )

        #expect(result.importedCount == 1)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)
        let tx = try #require(transactions.first)

        let ccEntry = try #require(tx.entries.first(where: { $0.account?.id == creditCard.id }))
        let contraEntry = try #require(tx.entries.first(where: { $0.account?.id == expense.id }))

        #expect(ccEntry.type == .credit)
        #expect(ccEntry.amount == 45.00)
        #expect(contraEntry.type == .debit)
        #expect(contraEntry.amount == 45.00)
    }

    @Test @MainActor
    func liabilityAccountNegativeAmountDebitLiabilityCreditContra() throws {
        let (_, context, service) = try makeService()

        let creditCard = Account(name: "Credit Card", type: .liability)
        let chequing = Account(name: "Chequing", type: .asset)
        context.insert(creditCard)
        context.insert(chequing)

        // Negative on liability = payment reducing the balance → debit the liability
        let rows = [
            row(["Date": "2026-01-15", "Payee": "Payment", "Amount": "-200.00"]),
        ]

        let result = try service.importRows(
            rows,
            mapping: signedAmountMapping,
            account: creditCard,
            contraAccount: chequing,
            fileName: "cc.csv"
        )

        #expect(result.importedCount == 1)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)
        let tx = try #require(transactions.first)

        let ccEntry = try #require(tx.entries.first(where: { $0.account?.id == creditCard.id }))
        let contraEntry = try #require(tx.entries.first(where: { $0.account?.id == chequing.id }))

        #expect(ccEntry.type == .debit)
        #expect(ccEntry.amount == 200.00)
        #expect(contraEntry.type == .credit)
        #expect(contraEntry.amount == 200.00)
    }

    // MARK: - 10. Memo column

    @Test @MainActor
    func memoColumnAppearsOnTransactionNotes() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let expense = Account(name: "Expenses", type: .expense)
        context.insert(chequing)
        context.insert(expense)

        let mapping = ColumnMapping(
            dateColumn: "Date",
            payeeColumn: "Payee",
            amountColumn: "Amount",
            memoColumn: "Memo"
        )

        let rows = [
            row(["Date": "2026-01-15", "Payee": "Coffee Shop", "Amount": "-4.50", "Memo": "Morning latte"]),
        ]

        let result = try service.importRows(
            rows,
            mapping: mapping,
            account: chequing,
            contraAccount: expense,
            fileName: "bank.csv"
        )

        #expect(result.importedCount == 1)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)
        let tx = try #require(transactions.first)

        #expect(tx.notes == "Morning latte")
    }

    @Test @MainActor
    func emptyMemoColumnResultsInNilNotes() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let expense = Account(name: "Expenses", type: .expense)
        context.insert(chequing)
        context.insert(expense)

        let mapping = ColumnMapping(
            dateColumn: "Date",
            payeeColumn: "Payee",
            amountColumn: "Amount",
            memoColumn: "Memo"
        )

        let rows = [
            row(["Date": "2026-01-15", "Payee": "Coffee Shop", "Amount": "-4.50", "Memo": ""]),
        ]

        let result = try service.importRows(
            rows,
            mapping: mapping,
            account: chequing,
            contraAccount: expense,
            fileName: "bank.csv"
        )

        #expect(result.importedCount == 1)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)
        let tx = try #require(transactions.first)
        #expect(tx.notes == nil)
    }

    // MARK: - 11. ImportRecord linkage

    @Test @MainActor
    func transactionsReferenceImportRecord() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let expense = Account(name: "Expenses", type: .expense)
        context.insert(chequing)
        context.insert(expense)

        let rows = [
            row(["Date": "2026-01-15", "Payee": "Store A", "Amount": "-20.00"], line: 2),
            row(["Date": "2026-01-16", "Payee": "Store B", "Amount": "-30.00"], line: 3),
        ]

        let result = try service.importRows(
            rows,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: expense,
            fileName: "jan.csv"
        )

        #expect(result.importedCount == 2)

        let importRecord = result.importRecord
        #expect(importRecord.fileName == "jan.csv")
        #expect(importRecord.rowCount == 2)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)

        for tx in transactions {
            #expect(tx.importRecord?.id == importRecord.id)
        }

        // Verify ImportRecord.transactions back-reference
        #expect(importRecord.transactions.count == 2)
    }

    // MARK: - 12. All rows errored produces empty import with errors list

    @Test @MainActor
    func allRowsErroredProducesZeroImportedCount() throws {
        let (_, context, service) = try makeService()

        let chequing = Account(name: "Chequing", type: .asset)
        let expense = Account(name: "Expenses", type: .expense)
        context.insert(chequing)
        context.insert(expense)

        let rows = [
            row(["Date": "bad-date", "Payee": "Store", "Amount": "-20.00"], line: 2),
            row(["Date": "2026-01-16", "Payee": "Store", "Amount": "bad-amount"], line: 3),
        ]

        let result = try service.importRows(
            rows,
            mapping: signedAmountMapping,
            account: chequing,
            contraAccount: expense,
            fileName: "bad.csv"
        )

        #expect(result.importedCount == 0)
        #expect(result.skippedDuplicates == 0)
        #expect(result.errors.count == 2)
        #expect(result.errors[0].lineNumber == 2)
        #expect(result.errors[1].lineNumber == 3)

        let txDescriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(txDescriptor)
        #expect(transactions.isEmpty)
    }
}

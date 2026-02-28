import Foundation
import Testing
import SwiftData
@testable import ShillingCore

@Suite("TransactionService")
struct TransactionServiceTests {

    // MARK: - Helpers

    /// Returns a fresh in-memory container, context, and service.
    @MainActor
    private func makeService() throws -> (ModelContainer, ModelContext, TransactionService) {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = TransactionService(context: context)
        return (container, context, service)
    }

    /// Inserts and returns two standard accounts: a checking asset and a groceries expense.
    @MainActor
    private func makeAccounts(context: ModelContext) -> (checking: Account, groceries: Account) {
        let checking = Account(name: "Checking", type: .asset)
        let groceries = Account(name: "Groceries", type: .expense)
        context.insert(checking)
        context.insert(groceries)
        return (checking, groceries)
    }

    // MARK: - createTransaction

    @Test @MainActor
    func createBalancedTransactionSucceeds() throws {
        let (_, context, service) = try makeService()
        let (checking, groceries) = makeAccounts(context: context)

        let date = Date()
        let transaction = try service.createTransaction(
            date: date,
            payee: "Whole Foods",
            notes: "Weekly shop",
            entries: [
                EntryData(account: groceries, amount: 85.00, type: .debit),
                EntryData(account: checking, amount: 85.00, type: .credit),
            ]
        )

        #expect(transaction.payee == "Whole Foods")
        #expect(transaction.notes == "Weekly shop")
        #expect(transaction.date == date)
        #expect(transaction.entries.count == 2)

        let debitEntry = try #require(transaction.entries.first(where: { $0.type == .debit }))
        #expect(debitEntry.amount == 85.00)
        #expect(debitEntry.account?.name == "Groceries")

        let creditEntry = try #require(transaction.entries.first(where: { $0.type == .credit }))
        #expect(creditEntry.amount == 85.00)
        #expect(creditEntry.account?.name == "Checking")
    }

    @Test @MainActor
    func createWithOneEntryThrowsInsufficientEntries() throws {
        let (_, context, service) = try makeService()
        let checking = Account(name: "Checking", type: .asset)
        context.insert(checking)

        #expect(throws: TransactionError.insufficientEntries) {
            try service.createTransaction(
                date: Date(),
                payee: "Solo",
                entries: [
                    EntryData(account: checking, amount: 100.00, type: .debit),
                ]
            )
        }
    }

    @Test @MainActor
    func createWithZeroAmountThrowsZeroOrNegativeAmount() throws {
        let (_, context, service) = try makeService()
        let (checking, groceries) = makeAccounts(context: context)

        #expect(throws: TransactionError.zeroOrNegativeAmount) {
            try service.createTransaction(
                date: Date(),
                payee: "Bad",
                entries: [
                    EntryData(account: groceries, amount: 0, type: .debit),
                    EntryData(account: checking, amount: 0, type: .credit),
                ]
            )
        }
    }

    @Test @MainActor
    func createWithNegativeAmountThrowsZeroOrNegativeAmount() throws {
        let (_, context, service) = try makeService()
        let (checking, groceries) = makeAccounts(context: context)

        #expect(throws: TransactionError.zeroOrNegativeAmount) {
            try service.createTransaction(
                date: Date(),
                payee: "Bad",
                entries: [
                    EntryData(account: groceries, amount: -50.00, type: .debit),
                    EntryData(account: checking, amount: -50.00, type: .credit),
                ]
            )
        }
    }

    @Test @MainActor
    func createUnbalancedTransactionThrowsUnbalancedEntries() throws {
        let (_, context, service) = try makeService()
        let (checking, groceries) = makeAccounts(context: context)

        do {
            try service.createTransaction(
                date: Date(),
                payee: "Unbalanced",
                entries: [
                    EntryData(account: groceries, amount: 100.00, type: .debit),
                    EntryData(account: checking, amount: 80.00, type: .credit),
                ]
            )
            Issue.record("Expected unbalancedEntries error but no error was thrown")
        } catch TransactionError.unbalancedEntries(let debitTotal, let creditTotal) {
            #expect(debitTotal == 100.00)
            #expect(creditTotal == 80.00)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - updateTransaction

    @Test @MainActor
    func updateTransactionReplacesEntries() throws {
        let (_, context, service) = try makeService()
        let (checking, groceries) = makeAccounts(context: context)
        let dining = Account(name: "Dining", type: .expense)
        context.insert(dining)

        let transaction = try service.createTransaction(
            date: Date(),
            payee: "Whole Foods",
            entries: [
                EntryData(account: groceries, amount: 85.00, type: .debit),
                EntryData(account: checking, amount: 85.00, type: .credit),
            ]
        )

        let newDate = Date(timeIntervalSinceNow: 86400)
        try service.updateTransaction(
            transaction,
            date: newDate,
            payee: "Restaurant",
            notes: "Dinner out",
            entries: [
                EntryData(account: dining, amount: 45.00, type: .debit),
                EntryData(account: checking, amount: 45.00, type: .credit),
            ]
        )

        #expect(transaction.payee == "Restaurant")
        #expect(transaction.notes == "Dinner out")
        #expect(transaction.date == newDate)
        #expect(transaction.entries.count == 2)

        let debitEntry = try #require(transaction.entries.first(where: { $0.type == .debit }))
        #expect(debitEntry.amount == 45.00)
        #expect(debitEntry.account?.name == "Dining")
    }

    // MARK: - deleteTransaction

    @Test @MainActor
    func deleteTransactionRemovesIt() throws {
        let (_, context, service) = try makeService()
        let (checking, groceries) = makeAccounts(context: context)

        let transaction = try service.createTransaction(
            date: Date(),
            payee: "To Delete",
            entries: [
                EntryData(account: groceries, amount: 20.00, type: .debit),
                EntryData(account: checking, amount: 20.00, type: .credit),
            ]
        )

        service.deleteTransaction(transaction)
        try context.save()

        let descriptor = FetchDescriptor<Transaction>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.isEmpty)

        // Cascade: entries should also be gone
        let entryDescriptor = FetchDescriptor<Entry>()
        let remainingEntries = try context.fetch(entryDescriptor)
        #expect(remainingEntries.isEmpty)
    }

    // MARK: - fetchTransactions

    @Test @MainActor
    func fetchByDateRange() throws {
        let (_, context, service) = try makeService()
        let (checking, groceries) = makeAccounts(context: context)

        let jan1 = Date(timeIntervalSince1970: 1_735_689_600) // 2025-01-01
        let feb1 = Date(timeIntervalSince1970: 1_738_368_000) // 2025-02-01
        let mar1 = Date(timeIntervalSince1970: 1_740_787_200) // 2025-03-01

        try service.createTransaction(date: jan1, payee: "January", entries: [
            EntryData(account: groceries, amount: 10.00, type: .debit),
            EntryData(account: checking, amount: 10.00, type: .credit),
        ])
        try service.createTransaction(date: feb1, payee: "February", entries: [
            EntryData(account: groceries, amount: 20.00, type: .debit),
            EntryData(account: checking, amount: 20.00, type: .credit),
        ])
        try service.createTransaction(date: mar1, payee: "March", entries: [
            EntryData(account: groceries, amount: 30.00, type: .debit),
            EntryData(account: checking, amount: 30.00, type: .credit),
        ])

        let results = try service.fetchTransactions(from: jan1, to: feb1)
        #expect(results.count == 2)
        let payees = results.map(\.payee).sorted()
        #expect(payees.contains("January"))
        #expect(payees.contains("February"))
        #expect(!payees.contains("March"))
    }

    @Test @MainActor
    func fetchByAccount() throws {
        let (_, context, service) = try makeService()
        let (checking, groceries) = makeAccounts(context: context)
        let rent = Account(name: "Rent", type: .expense)
        context.insert(rent)

        try service.createTransaction(date: Date(), payee: "Grocery Store", entries: [
            EntryData(account: groceries, amount: 50.00, type: .debit),
            EntryData(account: checking, amount: 50.00, type: .credit),
        ])
        try service.createTransaction(date: Date(), payee: "Landlord", entries: [
            EntryData(account: rent, amount: 1500.00, type: .debit),
            EntryData(account: checking, amount: 1500.00, type: .credit),
        ])

        let groceryTransactions = try service.fetchTransactions(account: groceries)
        #expect(groceryTransactions.count == 1)
        #expect(groceryTransactions.first?.payee == "Grocery Store")

        // Checking is used by both transactions
        let checkingTransactions = try service.fetchTransactions(account: checking)
        #expect(checkingTransactions.count == 2)
    }

    @Test @MainActor
    func fetchByPayeeCaseInsensitive() throws {
        let (_, context, service) = try makeService()
        let (checking, groceries) = makeAccounts(context: context)

        try service.createTransaction(date: Date(), payee: "Whole Foods Market", entries: [
            EntryData(account: groceries, amount: 60.00, type: .debit),
            EntryData(account: checking, amount: 60.00, type: .credit),
        ])
        try service.createTransaction(date: Date(), payee: "Amazon", entries: [
            EntryData(account: groceries, amount: 25.00, type: .debit),
            EntryData(account: checking, amount: 25.00, type: .credit),
        ])

        // lowercase search
        let results1 = try service.fetchTransactions(payee: "whole foods")
        #expect(results1.count == 1)
        #expect(results1.first?.payee == "Whole Foods Market")

        // uppercase search
        let results2 = try service.fetchTransactions(payee: "AMAZON")
        #expect(results2.count == 1)
        #expect(results2.first?.payee == "Amazon")

        // partial match
        let results3 = try service.fetchTransactions(payee: "foods")
        #expect(results3.count == 1)
    }

    // MARK: - createOpeningBalance

    @Test @MainActor
    func createOpeningBalanceForAssetAccount() throws {
        let (_, context, service) = try makeService()
        let checking = Account(name: "Checking", type: .asset)
        let openingBalances = Account(name: "Opening Balances", type: .equity)
        context.insert(checking)
        context.insert(openingBalances)

        let date = Date()
        let transaction = try service.createOpeningBalance(
            account: checking,
            amount: 1000.00,
            date: date,
            openingBalancesAccount: openingBalances
        )

        #expect(transaction.payee == "Opening Balance")
        #expect(transaction.entries.count == 2)

        // Asset account should be debited
        let debitEntry = try #require(transaction.entries.first(where: { $0.type == .debit }))
        #expect(debitEntry.account?.name == "Checking")
        #expect(debitEntry.amount == 1000.00)

        // Opening Balances equity should be credited
        let creditEntry = try #require(transaction.entries.first(where: { $0.type == .credit }))
        #expect(creditEntry.account?.name == "Opening Balances")
        #expect(creditEntry.amount == 1000.00)
    }

    @Test @MainActor
    func createOpeningBalanceForLiabilityAccount() throws {
        let (_, context, service) = try makeService()
        let creditCard = Account(name: "Credit Card", type: .liability)
        let openingBalances = Account(name: "Opening Balances", type: .equity)
        context.insert(creditCard)
        context.insert(openingBalances)

        let transaction = try service.createOpeningBalance(
            account: creditCard,
            amount: 500.00,
            date: Date(),
            openingBalancesAccount: openingBalances
        )

        #expect(transaction.entries.count == 2)

        // Opening Balances equity should be debited
        let debitEntry = try #require(transaction.entries.first(where: { $0.type == .debit }))
        #expect(debitEntry.account?.name == "Opening Balances")
        #expect(debitEntry.amount == 500.00)

        // Liability account should be credited (credit-normal = increasing the liability)
        let creditEntry = try #require(transaction.entries.first(where: { $0.type == .credit }))
        #expect(creditEntry.account?.name == "Credit Card")
        #expect(creditEntry.amount == 500.00)
    }
}

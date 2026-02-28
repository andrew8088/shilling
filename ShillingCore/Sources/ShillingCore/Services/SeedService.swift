import Foundation
import SwiftData

public struct SeedService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Public API

    /// Returns true if no accounts exist in the data store.
    public func needsSeed() throws -> Bool {
        let descriptor = FetchDescriptor<Account>()
        let count = try context.fetchCount(descriptor)
        return count == 0
    }

    /// Creates the minimum required accounts (Opening Balances equity, Interest expense).
    /// Idempotent — safe to call multiple times.
    public func seedDefaults() throws {
        guard try needsSeed() else { return }

        let accountService = AccountService(context: context)
        try accountService.create(name: "Opening Balances", type: .equity)
        try accountService.create(name: "Interest", type: .expense)
    }

    /// Seeds the minimum required accounts then adds a starter chart of accounts.
    /// Idempotent — accounts that already exist (by name at root level) are skipped.
    public func seedStarterChart() throws {
        try seedDefaults()

        let accountService = AccountService(context: context)
        let existing = try accountService.list(includeArchived: true)
        let existingNames = Set(existing.filter { $0.parent == nil }.map(\.name))

        let candidates: [(name: String, type: AccountType)] = [
            // Assets
            ("Chequing", .asset),
            ("Savings", .asset),
            // Liabilities
            ("Credit Card", .liability),
            ("Mortgage", .liability),
            // Expenses (Interest already created by seedDefaults)
            ("Groceries", .expense),
            ("Dining", .expense),
            ("Transport", .expense),
            ("Utilities", .expense),
            ("Housing", .expense),
            ("Entertainment", .expense),
            // Income
            ("Salary", .income),
            ("Other Income", .income),
        ]

        for candidate in candidates where !existingNames.contains(candidate.name) {
            try accountService.create(name: candidate.name, type: candidate.type)
        }
    }
}

import Foundation
import Testing
import SwiftData
@testable import ShillingCore

@Suite("SeedService")
struct SeedServiceTests {

    // MARK: - needsSeed

    @Test @MainActor func needsSeedReturnsTrueOnEmptyStore() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = SeedService(context: context)

        #expect(try service.needsSeed() == true)
    }

    @Test @MainActor func needsSeedReturnsFalseAfterSeeding() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = SeedService(context: context)

        try service.seedDefaults()

        #expect(try service.needsSeed() == false)
    }

    // MARK: - seedDefaults

    @Test @MainActor func seedDefaultsCreatesOpeningBalancesAndInterest() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = SeedService(context: context)

        try service.seedDefaults()

        let accountService = AccountService(context: context)
        let all = try accountService.list(includeArchived: true)

        #expect(all.count == 2)
        #expect(all.contains(where: { $0.name == "Opening Balances" }))
        #expect(all.contains(where: { $0.name == "Interest" }))
    }

    @Test @MainActor func seedDefaultsIsIdempotent() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = SeedService(context: context)

        try service.seedDefaults()
        try service.seedDefaults()

        let accountService = AccountService(context: context)
        let all = try accountService.list(includeArchived: true)

        // Still exactly 2 accounts — no duplicates
        #expect(all.count == 2)
    }

    @Test @MainActor func openingBalancesHasEquityType() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = SeedService(context: context)

        try service.seedDefaults()

        let accountService = AccountService(context: context)
        let all = try accountService.list(includeArchived: true)
        let openingBalances = try #require(all.first(where: { $0.name == "Opening Balances" }))

        #expect(openingBalances.type == .equity)
    }

    @Test @MainActor func interestHasExpenseType() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = SeedService(context: context)

        try service.seedDefaults()

        let accountService = AccountService(context: context)
        let all = try accountService.list(includeArchived: true)
        let interest = try #require(all.first(where: { $0.name == "Interest" }))

        #expect(interest.type == .expense)
    }

    // MARK: - seedStarterChart

    @Test @MainActor func seedStarterChartCreatesAllExpectedAccounts() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = SeedService(context: context)

        try service.seedStarterChart()

        let accountService = AccountService(context: context)
        let all = try accountService.list(includeArchived: true)
        let names = Set(all.map(\.name))

        // Defaults
        #expect(names.contains("Opening Balances"))
        #expect(names.contains("Interest"))
        // Assets
        #expect(names.contains("Chequing"))
        #expect(names.contains("Savings"))
        // Liabilities
        #expect(names.contains("Credit Card"))
        #expect(names.contains("Mortgage"))
        // Expenses
        #expect(names.contains("Groceries"))
        #expect(names.contains("Dining"))
        #expect(names.contains("Transport"))
        #expect(names.contains("Utilities"))
        #expect(names.contains("Housing"))
        #expect(names.contains("Entertainment"))
        // Income
        #expect(names.contains("Salary"))
        #expect(names.contains("Other Income"))
    }

    @Test @MainActor func seedStarterChartIsIdempotent() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = SeedService(context: context)

        try service.seedStarterChart()
        let countAfterFirst = try AccountService(context: context).list(includeArchived: true).count

        try service.seedStarterChart()
        let countAfterSecond = try AccountService(context: context).list(includeArchived: true).count

        #expect(countAfterFirst == countAfterSecond)
    }
}

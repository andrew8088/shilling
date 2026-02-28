import Foundation
import Testing
import SwiftData
@testable import ShillingCore

@Suite("AccountService")
struct AccountServiceTests {

    // MARK: - Create

    @Test @MainActor func createAccountSuccessfully() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = AccountService(context: context)

        let account = try service.create(name: "Checking", type: .asset)

        #expect(account.name == "Checking")
        #expect(account.type == .asset)
        #expect(account.parent == nil)
        #expect(account.isArchived == false)
        #expect(account.notes == nil)
    }

    @Test @MainActor func createDuplicateNameAtRootThrows() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = AccountService(context: context)

        try service.create(name: "Checking", type: .asset)

        #expect(throws: AccountError.duplicateName("Checking")) {
            try service.create(name: "Checking", type: .asset)
        }
    }

    @Test @MainActor func createSameNameUnderDifferentParentsSucceeds() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = AccountService(context: context)

        let parentA = try service.create(name: "Current Assets", type: .asset)
        let parentB = try service.create(name: "Fixed Assets", type: .asset)

        let childA = try service.create(name: "Checking", type: .asset, parent: parentA)
        let childB = try service.create(name: "Checking", type: .asset, parent: parentB)

        #expect(childA.parent?.id == parentA.id)
        #expect(childB.parent?.id == parentB.id)
    }

    // MARK: - Update

    @Test @MainActor func updateAccountName() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = AccountService(context: context)

        let account = try service.create(name: "Chequing", type: .asset)

        try service.update(
            account: account,
            name: "Checking",
            type: .asset,
            parent: nil,
            isArchived: false,
            notes: nil
        )

        #expect(account.name == "Checking")
    }

    @Test @MainActor func updateToDuplicateNameThrows() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = AccountService(context: context)

        try service.create(name: "Checking", type: .asset)
        let savings = try service.create(name: "Savings", type: .asset)

        #expect(throws: AccountError.duplicateName("Checking")) {
            try service.update(
                account: savings,
                name: "Checking",
                type: .asset,
                parent: nil,
                isArchived: false,
                notes: nil
            )
        }
    }

    @Test @MainActor func updateToSameNameSucceeds() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = AccountService(context: context)

        let account = try service.create(name: "Checking", type: .asset)

        // Updating to its own current name should not throw
        try service.update(
            account: account,
            name: "Checking",
            type: .asset,
            parent: nil,
            isArchived: false,
            notes: nil
        )

        #expect(account.name == "Checking")
    }

    // MARK: - Archive

    @Test @MainActor func archiveAccount() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = AccountService(context: context)

        let account = try service.create(name: "Old Bank", type: .asset)
        #expect(account.isArchived == false)

        service.archive(account: account)

        #expect(account.isArchived == true)
    }

    // MARK: - Delete

    @Test @MainActor func deleteAccountWithNoEntriesSucceeds() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = AccountService(context: context)

        let account = try service.create(name: "Temp", type: .asset)
        try context.save()

        try service.delete(account: account)
        try context.save()

        let descriptor = FetchDescriptor<Account>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.isEmpty)
    }

    @Test @MainActor func deleteAccountWithEntriesThrows() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = AccountService(context: context)

        let account = try service.create(name: "Checking", type: .asset)
        let entry = Entry(account: account, amount: 100.00, type: .debit)
        context.insert(entry)
        try context.save()

        #expect(throws: AccountError.hasEntries) {
            try service.delete(account: account)
        }
    }

    // MARK: - List

    @Test @MainActor func listAccountsByType() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = AccountService(context: context)

        try service.create(name: "Checking", type: .asset)
        try service.create(name: "Savings", type: .asset)
        try service.create(name: "Rent", type: .expense)

        let assets = try service.list(type: .asset)
        let expenses = try service.list(type: .expense)

        #expect(assets.count == 2)
        #expect(expenses.count == 1)
        #expect(assets.allSatisfy { $0.type == .asset })
    }

    @Test @MainActor func listExcludesArchivedByDefault() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = AccountService(context: context)

        let active = try service.create(name: "Checking", type: .asset)
        let archived = try service.create(name: "Old Bank", type: .asset)
        service.archive(account: archived)

        let accounts = try service.list()

        #expect(accounts.count == 1)
        #expect(accounts.first?.id == active.id)
    }

    @Test @MainActor func listIncludesArchivedWhenRequested() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = AccountService(context: context)

        try service.create(name: "Checking", type: .asset)
        let archived = try service.create(name: "Old Bank", type: .asset)
        service.archive(account: archived)

        let accounts = try service.list(includeArchived: true)

        #expect(accounts.count == 2)
    }

    @Test @MainActor func listIsSortedByName() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = AccountService(context: context)

        try service.create(name: "Zephyr", type: .asset)
        try service.create(name: "Alpha", type: .asset)
        try service.create(name: "Middle", type: .asset)

        let accounts = try service.list()
        let names = accounts.map(\.name)

        #expect(names == ["Alpha", "Middle", "Zephyr"])
    }

    // MARK: - List Hierarchy

    @Test @MainActor func listHierarchyReturnsRootAccountsOfType() throws {
        let container = try ModelContainerSetup.makeInMemory()
        let context = ModelContext(container)
        let service = AccountService(context: context)

        let assets = try service.create(name: "Assets", type: .asset)
        let checking = try service.create(name: "Checking", type: .asset, parent: assets)
        try service.create(name: "Expenses", type: .expense)

        let hierarchy = try service.listHierarchy(type: .asset)

        // Only root asset accounts (no parent)
        #expect(hierarchy.count == 1)
        #expect(hierarchy.first?.name == "Assets")
        // Children are accessible via the relationship
        #expect(hierarchy.first?.children.first?.id == checking.id)
    }
}

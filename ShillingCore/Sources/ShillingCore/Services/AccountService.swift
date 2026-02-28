import Foundation
import SwiftData

// MARK: - AccountError

public enum AccountError: Error, LocalizedError, Equatable {
    case duplicateName(String)
    case hasEntries

    public var errorDescription: String? {
        switch self {
        case .duplicateName(let name):
            return "An account named '\(name)' already exists at this level."
        case .hasEntries:
            return "This account has entries and cannot be deleted. Consider archiving it instead."
        }
    }
}

// MARK: - AccountService

public struct AccountService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: Create

    /// Creates a new account. Throws `AccountError.duplicateName` if a sibling with the same name exists.
    @discardableResult
    public func create(
        name: String,
        type: AccountType,
        parent: Account? = nil,
        notes: String? = nil
    ) throws -> Account {
        try validateUniqueName(name, parent: parent, excluding: nil)
        let account = Account(name: name, type: type, parent: parent, notes: notes)
        context.insert(account)
        return account
    }

    // MARK: Update

    /// Updates fields on an existing account. Re-validates name uniqueness when the name changes.
    public func update(
        account: Account,
        name: String,
        type: AccountType,
        parent: Account?,
        isArchived: Bool,
        notes: String?
    ) throws {
        if name != account.name || parent?.id != account.parent?.id {
            try validateUniqueName(name, parent: parent, excluding: account)
        }
        account.name = name
        account.type = type
        account.parent = parent
        account.isArchived = isArchived
        account.notes = notes
    }

    // MARK: Archive

    /// Sets `isArchived` to true on the account.
    public func archive(account: Account) {
        account.isArchived = true
    }

    // MARK: Delete

    /// Deletes the account. Throws `AccountError.hasEntries` if the account has any entries.
    public func delete(account: Account) throws {
        guard account.entries.isEmpty else {
            throw AccountError.hasEntries
        }
        context.delete(account)
    }

    // MARK: List

    /// Returns accounts filtered by type and archived status, sorted by name.
    public func list(type: AccountType? = nil, includeArchived: Bool = false) throws -> [Account] {
        let descriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.name)]
        )

        let accounts = try context.fetch(descriptor)

        return accounts.filter { account in
            if let type, account.type != type { return false }
            if !includeArchived && account.isArchived { return false }
            return true
        }
    }

    /// Returns root accounts (no parent) of the given type, with children populated via relationship.
    public func listHierarchy(type: AccountType) throws -> [Account] {
        let descriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.name)]
        )

        let accounts = try context.fetch(descriptor)

        return accounts.filter { account in
            account.parent == nil && account.type == type
        }
    }

    // MARK: Private Helpers

    private func validateUniqueName(_ name: String, parent: Account?, excluding account: Account?) throws {
        let descriptor = FetchDescriptor<Account>()
        let allAccounts = try context.fetch(descriptor)

        let siblings = allAccounts.filter { candidate in
            // Exclude the account being updated
            if let account, candidate.id == account.id { return false }
            // Match on parent scope
            return candidate.parent?.id == parent?.id
        }

        if siblings.contains(where: { $0.name == name }) {
            throw AccountError.duplicateName(name)
        }
    }
}

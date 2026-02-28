import Foundation
import SwiftData

@Model
public final class Account {
    public var id: UUID
    public var name: String
    public var accountType: String

    @Relationship(inverse: \Account.children)
    public var parent: Account?
    @Relationship
    public var children: [Account]
    public var isArchived: Bool
    public var notes: String?
    public var createdAt: Date

    @Relationship(inverse: \Entry.account)
    public var entries: [Entry]

    @Relationship(inverse: \Budget.account)
    public var budgets: [Budget]

    public var type: AccountType {
        get { AccountType(rawValue: accountType)! }
        set { accountType = newValue.rawValue }
    }

    public init(
        name: String,
        type: AccountType,
        parent: Account? = nil,
        isArchived: Bool = false,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.accountType = type.rawValue
        self.parent = parent
        self.children = []
        self.isArchived = isArchived
        self.notes = notes
        self.createdAt = Date()
        self.entries = []
        self.budgets = []
    }
}

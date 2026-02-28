import Foundation
import SwiftData

@Model
public final class Entry {
    public var id: UUID
    public var transaction: Transaction?
    public var account: Account?
    public var amount: Decimal
    public var entryType: String
    public var memo: String?

    public var type: EntryType {
        get { EntryType(rawValue: entryType)! }
        set { entryType = newValue.rawValue }
    }

    public init(
        account: Account,
        amount: Decimal,
        type: EntryType,
        memo: String? = nil
    ) {
        self.id = UUID()
        self.account = account
        self.amount = amount
        self.entryType = type.rawValue
        self.memo = memo
    }
}

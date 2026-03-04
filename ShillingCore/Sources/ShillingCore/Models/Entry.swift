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
        get {
            decodeEntryType(from: entryType) ?? .debit
        }
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

    private func decodeEntryType(from rawValue: String) -> EntryType? {
        if let decoded = EntryType(rawValue: rawValue) {
            return decoded
        }

        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return EntryType(rawValue: normalized)
    }
}

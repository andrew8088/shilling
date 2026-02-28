import Foundation
import SwiftData

@Model
public final class Budget {
    public var id: UUID
    public var account: Account?
    public var year: Int
    public var month: Int
    public var amount: Decimal

    public init(
        account: Account,
        year: Int,
        month: Int,
        amount: Decimal
    ) {
        self.id = UUID()
        self.account = account
        self.year = year
        self.month = month
        self.amount = amount
    }
}

import Foundation

public enum AccountType: String, Codable, CaseIterable, Sendable {
    case asset
    case liability
    case equity
    case income
    case expense

    /// Whether this account type uses debit-normal balance calculation.
    /// Debit-normal: balance = sum(debits) - sum(credits)
    /// Credit-normal: balance = sum(credits) - sum(debits)
    public var isDebitNormal: Bool {
        switch self {
        case .asset, .expense:
            return true
        case .liability, .equity, .income:
            return false
        }
    }
}

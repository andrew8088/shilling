import Foundation

public enum EntryType: String, Codable, CaseIterable, Sendable {
    case debit
    case credit
}

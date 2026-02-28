import Foundation
import SwiftData

@Model
public final class Transaction {
    public var id: UUID
    public var date: Date
    public var payee: String
    public var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \Entry.transaction)
    public var entries: [Entry]

    public var importRecord: ImportRecord?
    public var createdAt: Date

    public init(
        date: Date,
        payee: String,
        notes: String? = nil,
        importRecord: ImportRecord? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.payee = payee
        self.notes = notes
        self.entries = []
        self.importRecord = importRecord
        self.createdAt = Date()
    }
}

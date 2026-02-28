import Foundation
import SwiftData

@Model
public final class ImportRecord {
    public var id: UUID
    public var fileName: String
    public var importedAt: Date
    public var rowCount: Int

    @Relationship(inverse: \Transaction.importRecord)
    public var transactions: [Transaction]

    public init(
        fileName: String,
        rowCount: Int
    ) {
        self.id = UUID()
        self.fileName = fileName
        self.importedAt = Date()
        self.rowCount = rowCount
        self.transactions = []
    }
}

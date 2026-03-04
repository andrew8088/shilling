import Foundation
import SwiftData

public enum ModelContainerSetup {
    public static let schema = Schema([
        Account.self,
        Transaction.self,
        Entry.self,
        Budget.self,
        ImportRecord.self,
    ])

    /// Creates a ModelContainer for the default on-disk store.
    public static func makeDefault() throws -> ModelContainer {
        let config = ModelConfiguration("Shilling", schema: schema)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Creates an in-memory ModelContainer for testing.
    public static func makeInMemory() throws -> ModelContainer {
        // Explicit name avoids SwiftData bundle-name inference in headless CI test runners.
        let config = ModelConfiguration("ShillingTests", schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

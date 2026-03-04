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
        // SwiftData in-memory stores can crash on older CI toolchains when Bundle metadata is absent.
        // Use an isolated temporary store URL per container to keep tests hermetic across environments.
        let testsDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "shilling-tests",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: testsDir, withIntermediateDirectories: true)
        let storeURL = testsDir.appendingPathComponent("\(UUID().uuidString).store")
        let config = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

import Foundation
import ShillingCore
import SwiftData

enum DataStore {
    static func makeContainer(dataDir: String?) throws -> ModelContainer {
        if let dataDir {
            let url = URL(fileURLWithPath: dataDir)
            let config = ModelConfiguration(
                schema: ModelContainerSetup.schema,
                url: url.appendingPathComponent("shilling.store")
            )
            return try ModelContainer(for: ModelContainerSetup.schema, configurations: [config])
        }
        return try ModelContainerSetup.makeDefault()
    }
}

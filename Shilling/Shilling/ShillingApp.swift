import SwiftData
import SwiftUI
import ShillingCore

@main
struct ShillingApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainerSetup.makeDefault()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}

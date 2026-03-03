import SwiftUI
import SwiftData
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
                .frame(minWidth: 700, minHeight: 400)
        }
        .defaultSize(width: 900, height: 600)
        .modelContainer(container)
        #if DEBUG
        .commands {
            CommandMenu("Debug") {
                Button("Load Sample Data") {
                    loadFixtures()
                }
                .keyboardShortcut("D", modifiers: [.command, .shift])

                Button("Reset All Data") {
                    resetAndReseed()
                }
            }
        }
        #endif
    }

    #if DEBUG
    private func loadFixtures() {
        let context = container.mainContext
        do {
            try DevFixtures.seed(context: context)
        } catch {
            print("Fixture error: \(error)")
        }
    }

    private func resetAndReseed() {
        let context = container.mainContext
        do {
            try context.delete(model: Entry.self)
            try context.delete(model: Txn.self)
            try context.delete(model: Budget.self)
            try context.delete(model: Account.self)
            try context.save()
            let seed = SeedService(context: context)
            try seed.seedStarterChart()
            try DevFixtures.seed(context: context)
        } catch {
            print("Reset error: \(error)")
        }
    }
    #endif
}

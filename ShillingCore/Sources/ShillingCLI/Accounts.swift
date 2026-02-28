import ArgumentParser
import Foundation
import ShillingCore
import SwiftData

struct Accounts: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage accounts",
        subcommands: [
            List.self,
        ],
        defaultSubcommand: List.self
    )

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all accounts"
        )

        @Option(name: .long, help: "Custom data directory path")
        var dataDir: String?

        @Flag(name: .long, help: "Output as JSON")
        var json: Bool = false

        func run() throws {
            let container = try DataStore.makeContainer(dataDir: dataDir)
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<Account>(
                sortBy: [SortDescriptor(\.name)]
            )
            let accounts = try context.fetch(descriptor)

            if json {
                let output = accounts.map { account in
                    [
                        "id": account.id.uuidString,
                        "name": account.name,
                        "type": account.type.rawValue,
                        "isArchived": account.isArchived ? "true" : "false",
                    ]
                }
                let data = try JSONSerialization.data(
                    withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
                print(String(data: data, encoding: .utf8)!)
            } else {
                if accounts.isEmpty {
                    print("No accounts.")
                    return
                }
                for account in accounts {
                    let archived = account.isArchived ? " (archived)" : ""
                    print("\(account.name) [\(account.type.rawValue)]\(archived)")
                }
            }
        }
    }
}

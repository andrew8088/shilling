import ArgumentParser
import ShillingCore

@main
struct ShillingCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "shilling",
        abstract: "Shilling — personal finance CLI",
        version: ShillingCoreInfo.version,
        subcommands: [
            Accounts.self,
        ]
    )
}

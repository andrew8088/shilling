import SwiftUI
import SwiftData
import ShillingCore

struct AccountPicker: View {
    let label: String
    @Binding var selection: Account?
    var filter: ((Account) -> Bool)? = nil

    @Query(sort: \Account.name) private var allAccounts: [Account]

    private var accounts: [Account] {
        let active = allAccounts.filter { !$0.isArchived }
        if let filter {
            return active.filter(filter)
        }
        return active
    }

    private var grouped: [(AccountType, [Account])] {
        let byType = Dictionary(grouping: accounts) { $0.type }
        return AccountType.allCases.compactMap { type in
            guard let accounts = byType[type], !accounts.isEmpty else { return nil }
            return (type, accounts)
        }
    }

    var body: some View {
        Picker(label, selection: $selection) {
            Text("None").tag(Account?.none)
            ForEach(grouped, id: \.0) { type, accounts in
                Section(type.rawValue.capitalized) {
                    ForEach(accounts, id: \.id) { account in
                        Text(account.name).tag(Account?.some(account))
                    }
                }
            }
        }
    }
}

import SwiftUI
import SwiftData
import ShillingCore

struct SidebarView: View {
    @Binding var selection: NavigationItem?
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.name) private var allAccounts: [Account]

    @State private var showingNewAccountSheet = false
    @State private var showArchived = false

    private func rootAccounts(for type: AccountType) -> [Account] {
        allAccounts.filter { account in
            account.parent == nil
                && account.type == type
                && (showArchived || !account.isArchived)
        }
    }

    var body: some View {
        List(selection: $selection) {
            Section("Accounts") {
                ForEach(AccountType.allCases, id: \.self) { type in
                    let roots = rootAccounts(for: type)
                    if !roots.isEmpty {
                        DisclosureGroup(type.rawValue.capitalized) {
                            ForEach(roots, id: \.id) { account in
                                accountTree(account)
                            }
                        }
                    }
                }
            }

            Section {
                NavigationLink(value: NavigationItem.transactions) {
                    Label("Transactions", systemImage: "list.bullet.rectangle")
                }
                NavigationLink(value: NavigationItem.budget) {
                    Label("Budget", systemImage: "chart.bar")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Shilling")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewAccountSheet = true
                } label: {
                    Label("New Account", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $showArchived) {
                    Label("Show Archived", systemImage: "archivebox")
                }
                .toggleStyle(.checkbox)
            }
        }
        .sheet(isPresented: $showingNewAccountSheet) {
            AccountFormSheet(account: nil)
        }
    }

    @ViewBuilder
    private func accountTree(_ account: Account) -> some View {
        let children = account.children
            .filter { showArchived || !$0.isArchived }
            .sorted { $0.name < $1.name }

        if children.isEmpty {
            NavigationLink(value: NavigationItem.account(account)) {
                AccountTreeRow(account: account)
            }
        } else {
            DisclosureGroup {
                ForEach(children, id: \.id) { child in
                    NavigationLink(value: NavigationItem.account(child)) {
                        AccountTreeRow(account: child)
                    }
                }
            } label: {
                NavigationLink(value: NavigationItem.account(account)) {
                    AccountTreeRow(account: account)
                }
            }
        }
    }
}

import SwiftUI
import SwiftData
import ShillingCore

struct SidebarView: View {
    @Binding var selection: NavigationItem?
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.name) private var allAccounts: [Account]

    @State private var showingNewAccountSheet = false
    @State private var showingImportSheet = false
    @State private var showArchived = false

    private func rootAccounts(for type: AccountType) -> [Account] {
        allAccounts.filter { account in
            account.parent == nil
                && account.type == type
                && (showArchived || !account.isArchived)
        }
    }

    private func icon(for type: AccountType) -> String {
        switch type {
        case .asset:     return "banknote"
        case .liability: return "creditcard"
        case .equity:    return "building.columns"
        case .income:    return "arrow.down.circle"
        case .expense:   return "cart"
        }
    }

    private func typeTotal(for type: AccountType) -> Decimal {
        let service = BalanceService(context: context)
        return rootAccounts(for: type).reduce(Decimal.zero) { $0 + service.rollupBalance(for: $1) }
    }

    var body: some View {
        List(selection: $selection) {
            NavigationLink(value: NavigationItem.dashboard) {
                Label("Dashboard", systemImage: "house")
            }

            Section("Accounts") {
                ForEach(AccountType.allCases, id: \.self) { type in
                    let roots = rootAccounts(for: type)
                    if !roots.isEmpty {
                        DisclosureGroup {
                            ForEach(roots, id: \.id) { account in
                                accountTree(account)
                            }
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: icon(for: type))
                                    .font(.shillingCaption)
                                    .foregroundStyle(Color.shillingTextSecondary)
                                    .frame(width: 16)
                                Text(type.rawValue.capitalized)
                                    .font(.shillingSubheading)
                                    .foregroundStyle(Color.shillingTextPrimary)
                                Spacer()
                                Text(FormatHelpers.currency(typeTotal(for: type)))
                                    .font(.shillingCaption)
                                    .monospacedDigit()
                                    .foregroundStyle(Color.shillingTextTertiary)
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
                NavigationLink(value: NavigationItem.reports) {
                    Label("Reports", systemImage: "chart.xyaxis.line")
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
                Button {
                    showingImportSheet = true
                } label: {
                    Label("Import CSV", systemImage: "square.and.arrow.down")
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
        .sheet(isPresented: $showingImportSheet) {
            ImportCSVView()
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

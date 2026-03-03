import SwiftUI
import SwiftData
import ShillingCore

enum NavigationItem: Hashable {
    case dashboard
    case account(Account)
    case transactions
    case budget
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var selection: NavigationItem? = .dashboard
    @State private var seeded = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            detailView
        }
        .task {
            guard !seeded else { return }
            let seed = SeedService(context: context)
            do {
                if try seed.needsSeed() {
                    try seed.seedStarterChart()
                    try context.save()
                }
            } catch {
                print("Seed error: \(error)")
            }
            seeded = true
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .dashboard:
            DashboardView(selection: $selection)
        case .account(let account):
            AccountDetailView(account: account)
        case .transactions:
            TransactionListView()
        case .budget:
            BudgetView()
        case nil:
            DashboardView(selection: $selection)
        }
    }
}

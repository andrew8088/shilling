import SwiftUI
import SwiftData
import ShillingCore

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            Text("Select an item")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct SidebarView: View {
    var body: some View {
        List {
            NavigationLink("Accounts", value: "accounts")
            NavigationLink("Transactions", value: "transactions")
            NavigationLink("Budgets", value: "budgets")
        }
        .navigationTitle("Shilling")
    }
}

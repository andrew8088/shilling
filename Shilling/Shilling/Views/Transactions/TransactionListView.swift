import SwiftUI
import SwiftData
import ShillingCore

struct TransactionListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Txn.date, order: .reverse) private var allTransactions: [Txn]

    @State private var searchText = ""
    @State private var filterAccount: Account? = nil
    @State private var startDate: Date? = nil
    @State private var endDate: Date? = nil
    @State private var showingNewTransactionSheet = false
    @State private var selectedTransaction: Txn? = nil

    private var filtered: [Txn] {
        allTransactions.filter { tx in
            if let filterAccount {
                let id = filterAccount.id
                guard tx.entries.contains(where: { $0.account?.id == id }) else { return false }
            }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                guard tx.payee.lowercased().contains(q) else { return false }
            }
            if let startDate, tx.date < startDate { return false }
            if let endDate, tx.date > endDate { return false }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            if filtered.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.rectangle",
                    title: "No Transactions",
                    message: searchText.isEmpty && filterAccount == nil
                        ? "Create a transaction to get started."
                        : "No transactions match the current filters."
                )
            } else {
                List(filtered, id: \.id, selection: $selectedTransaction) { transaction in
                    TransactionRow(transaction: transaction)
                        .tag(transaction)
                }
            }
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewTransactionSheet = true
                } label: {
                    Label("New Transaction", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewTransactionSheet) {
            TransactionFormSheet(transaction: nil)
        }
        .sheet(item: $selectedTransaction) { tx in
            TransactionFormSheet(transaction: tx)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search payee...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            AccountPicker(label: "Account", selection: $filterAccount)
                .frame(maxWidth: 200)

            if filterAccount != nil || !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                    filterAccount = nil
                    startDate = nil
                    endDate = nil
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
    }
}

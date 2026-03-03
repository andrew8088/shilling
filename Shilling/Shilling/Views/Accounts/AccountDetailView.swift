import SwiftUI
import SwiftData
import ShillingCore

struct AccountDetailView: View {
    let account: Account
    @Environment(\.modelContext) private var context
    @State private var showingEditSheet = false
    @State private var showingOpeningBalanceSheet = false
    @State private var runningBalances: [(transaction: Txn, balance: Decimal)] = []

    private var balance: Decimal {
        BalanceService(context: context).balance(for: account)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            registerTable
        }
        .navigationTitle(account.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit Account") { showingEditSheet = true }
                    Button("Set Opening Balance") { showingOpeningBalanceSheet = true }
                    Divider()
                    if account.isArchived {
                        Button("Unarchive") { unarchive() }
                    } else {
                        Button("Archive") { archive() }
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AccountFormSheet(account: account)
        }
        .sheet(isPresented: $showingOpeningBalanceSheet) {
            OpeningBalanceSheet(account: account)
        }
        .task(id: account.id) {
            loadRegister()
        }
        .onChange(of: account.entries.count) {
            loadRegister()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.type.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if account.isArchived {
                    Text("Archived")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.yellow.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(FormatHelpers.currency(balance))
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(balance < 0 ? .red : .primary)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var registerTable: some View {
        if runningBalances.isEmpty {
            EmptyStateView(
                icon: "doc.text",
                title: "No Transactions",
                message: "Transactions involving this account will appear here."
            )
        } else {
            List(runningBalances, id: \.transaction.id) { row in
                HStack {
                    Text(FormatHelpers.date(row.transaction.date))
                        .frame(width: 90, alignment: .leading)
                    Text(row.transaction.payee)
                        .frame(minWidth: 100, alignment: .leading)
                    Spacer()
                    Text(entryAmount(for: row.transaction))
                        .monospacedDigit()
                        .frame(width: 100, alignment: .trailing)
                    Text(FormatHelpers.currency(row.balance))
                        .monospacedDigit()
                        .foregroundStyle(row.balance < 0 ? .red : .primary)
                        .frame(width: 100, alignment: .trailing)
                }
            }
        }
    }

    private func entryAmount(for transaction: Txn) -> String {
        let entries = transaction.entries.filter { $0.account?.id == account.id }
        let debits = entries.filter { $0.type == .debit }.reduce(Decimal.zero) { $0 + $1.amount }
        let credits = entries.filter { $0.type == .credit }.reduce(Decimal.zero) { $0 + $1.amount }

        if debits > 0 && credits > 0 {
            return "D: \(FormatHelpers.currency(debits)) / C: \(FormatHelpers.currency(credits))"
        } else if debits > 0 {
            return FormatHelpers.currency(debits)
        } else {
            return "(\(FormatHelpers.currency(credits)))"
        }
    }

    private func loadRegister() {
        let service = BalanceService(context: context)
        do {
            runningBalances = try service.runningBalance(for: account)
        } catch {
            runningBalances = []
        }
    }

    private func archive() {
        AccountService(context: context).archive(account: account)
    }

    private func unarchive() {
        account.isArchived = false
    }
}

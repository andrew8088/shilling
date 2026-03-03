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
        VStack(spacing: Spacing.md) {
            header
            registerTable
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.shillingBackground)
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
        CardView {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(account.name)
                        .font(.shillingTitle)
                        .foregroundStyle(Color.shillingTextPrimary)

                    HStack(spacing: Spacing.xs) {
                        Text(account.type.rawValue.capitalized)
                            .font(.shillingLabel)
                            .foregroundStyle(Color.shillingTextSecondary)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, Spacing.xxs)
                            .background(Color.shillingSurfaceSecondary)
                            .clipShape(Capsule())

                        if account.isArchived {
                            Text("Archived")
                                .font(.shillingLabel)
                                .foregroundStyle(Color.shillingWarning)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, Spacing.xxs)
                                .background(Color.shillingWarning.opacity(0.16))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text("Current Balance")
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingTextSecondary)
                    AmountText(balance, font: .shillingLargeTitleMono)
                }
            }
        }
    }

    @ViewBuilder
    private var registerTable: some View {
        if runningBalances.isEmpty {
            EmptyStateView(
                icon: "doc.text",
                title: "No Transactions",
                message: "Transactions involving this account will appear here.",
                actions: [
                    .init(
                        "Set Opening Balance",
                        systemImage: "plus.circle",
                        isPrimary: true
                    ) {
                        showingOpeningBalanceSheet = true
                    }
                ]
            )
        } else {
            ScrollView {
                CardView {
                    VStack(spacing: 0) {
                        HStack(spacing: Spacing.sm) {
                            Text("Date")
                                .frame(width: 92, alignment: .leading)
                            Text("Payee")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Change")
                                .frame(width: 110, alignment: .trailing)
                            Text("Balance")
                                .frame(width: 110, alignment: .trailing)
                        }
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingTextSecondary)
                        .padding(.bottom, Spacing.xs)

                        Divider()

                        ForEach(Array(runningBalances.enumerated()), id: \.element.transaction.id) { index, row in
                            if index > 0 {
                                Divider()
                            }
                            HStack(spacing: Spacing.sm) {
                                Text(FormatHelpers.date(row.transaction.date))
                                    .font(.shillingCaption)
                                    .foregroundStyle(Color.shillingTextSecondary)
                                    .frame(width: 92, alignment: .leading)

                                Text(row.transaction.payee)
                                    .font(.shillingBody)
                                    .foregroundStyle(Color.shillingTextPrimary)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                AmountText(entryNetAmount(for: row.transaction), font: .shillingBodyMono)
                                    .frame(width: 110, alignment: .trailing)

                                AmountText(row.balance, font: .shillingBodyMono)
                                    .frame(width: 110, alignment: .trailing)
                            }
                            .padding(.vertical, Spacing.xs)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func entryNetAmount(for transaction: Txn) -> Decimal {
        transaction.entries
            .filter { $0.account?.id == account.id }
            .reduce(Decimal.zero) { total, entry in
                total + (entry.type == .debit ? entry.amount : -entry.amount)
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

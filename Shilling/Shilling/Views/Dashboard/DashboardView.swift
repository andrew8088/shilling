import SwiftUI
import SwiftData
import ShillingCore

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Binding var selection: NavigationItem?

    @Query(sort: \Account.name) private var allAccounts: [Account]
    @Query(sort: \Txn.date, order: .reverse) private var allTransactions: [Txn]

    @State private var budgetComparisons: [BudgetComparison] = []
    @State private var showingNewTransactionSheet = false
    @State private var showingImportSheet = false

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var currentMonth: Int { Calendar.current.component(.month, from: Date()) }

    var body: some View {
        ScrollView {
            VStack(spacing: ShillingLayout.sectionSpacing) {
                netWorthCard
                accountSummarySection
                budgetSummaryCard
                recentTransactionsSection
                quickActions
            }
            .padding(Spacing.xl)
        }
        .background(Color.shillingBackground)
        .navigationTitle("Dashboard")
        .task { loadBudget() }
        .sheet(isPresented: $showingNewTransactionSheet) {
            TransactionFormSheet(transaction: nil)
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportCSVView()
        }
    }

    // MARK: - Net Worth Card

    private var activeAccounts: [Account] {
        allAccounts.filter { !$0.isArchived }
    }

    private var totalAssets: Decimal {
        let service = BalanceService(context: context)
        return activeAccounts
            .filter { $0.type == .asset }
            .reduce(Decimal.zero) { $0 + service.balance(for: $1) }
    }

    private var totalLiabilities: Decimal {
        let service = BalanceService(context: context)
        return activeAccounts
            .filter { $0.type == .liability }
            .reduce(Decimal.zero) { $0 + service.balance(for: $1) }
    }

    private var netWorth: Decimal {
        totalAssets - totalLiabilities
    }

    private var netWorthCard: some View {
        CardView {
            VStack(spacing: Spacing.sm) {
                Text("Net Worth")
                    .font(.shillingCaption)
                    .foregroundStyle(Color.shillingTextSecondary)
                AmountText(netWorth, font: .shillingLargeTitleMono)
                HStack(spacing: Spacing.lg) {
                    VStack(spacing: Spacing.xxs) {
                        Text("Assets")
                            .font(.shillingCaption)
                            .foregroundStyle(Color.shillingTextTertiary)
                        Text(FormatHelpers.currency(totalAssets))
                            .font(.shillingBodyMono)
                            .foregroundStyle(Color.shillingTextSecondary)
                    }
                    VStack(spacing: Spacing.xxs) {
                        Text("Liabilities")
                            .font(.shillingCaption)
                            .foregroundStyle(Color.shillingTextTertiary)
                        Text(FormatHelpers.currency(totalLiabilities))
                            .font(.shillingBodyMono)
                            .foregroundStyle(Color.shillingTextSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Account Summary

    private var accountTypeGroups: [(type: AccountType, accounts: [Account], total: Decimal)] {
        let service = BalanceService(context: context)
        return [AccountType.asset, .liability, .income, .expense]
            .compactMap { type in
                let accounts = activeAccounts.filter { $0.type == type && $0.parent == nil }
                guard !accounts.isEmpty else { return nil }
                let total = accounts.reduce(Decimal.zero) { $0 + service.balance(for: $1) }
                return (type: type, accounts: accounts, total: total)
            }
    }

    private var accountSummarySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Accounts", subtitle: "\(activeAccounts.filter { $0.parent == nil }.count) accounts")
            ForEach(accountTypeGroups, id: \.type) { group in
                CardView {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(group.type.rawValue.capitalized)
                                .font(.shillingSubheading)
                                .foregroundStyle(Color.shillingTextPrimary)
                            Text("\(group.accounts.count) account\(group.accounts.count == 1 ? "" : "s")")
                                .font(.shillingCaption)
                                .foregroundStyle(Color.shillingTextTertiary)
                        }
                        Spacer()
                        AmountText(group.total, font: .shillingAmountMono)
                    }
                }
            }
        }
    }

    // MARK: - Budget Summary

    private var totalBudgeted: Decimal {
        budgetComparisons.reduce(Decimal.zero) { $0 + $1.budgetAmount }
    }

    private var totalSpent: Decimal {
        budgetComparisons.reduce(Decimal.zero) { $0 + $1.actualAmount }
    }

    private var totalRemaining: Decimal {
        totalBudgeted - totalSpent
    }

    private var budgetProgress: Double {
        guard totalBudgeted > 0 else { return 0 }
        return NSDecimalNumber(decimal: totalSpent / totalBudgeted).doubleValue
    }

    private var budgetSummaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(
                "Budget",
                subtitle: FormatHelpers.monthYear(year: currentYear, month: currentMonth),
                action: { selection = .budget },
                actionLabel: "See All"
            )

            if budgetComparisons.isEmpty {
                CardView {
                    HStack {
                        Text("No budget targets set")
                            .font(.shillingBody)
                            .foregroundStyle(Color.shillingTextSecondary)
                        Spacer()
                        Button("Set Up Budget") { selection = .budget }
                            .buttonStyle(.borderless)
                            .font(.shillingBody)
                            .foregroundStyle(Color.shillingAccent)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                CardView {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ProgressBar(value: budgetProgress)

                        HStack {
                            Text("\(FormatHelpers.currency(totalSpent)) of \(FormatHelpers.currency(totalBudgeted))")
                                .font(.shillingBody)
                                .foregroundStyle(Color.shillingTextSecondary)
                            Spacer()
                            AmountText(totalRemaining)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Transactions

    private var recentTransactions: [Txn] {
        Array(allTransactions.prefix(10))
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(
                "Recent Transactions",
                action: { selection = .transactions },
                actionLabel: "View All"
            )

            if recentTransactions.isEmpty {
                CardView {
                    Text("No transactions yet")
                        .font(.shillingBody)
                        .foregroundStyle(Color.shillingTextSecondary)
                        .frame(maxWidth: .infinity)
                }
            } else {
                CardView {
                    VStack(spacing: 0) {
                        ForEach(Array(recentTransactions.enumerated()), id: \.element.id) { index, tx in
                            if index > 0 {
                                Divider().padding(.vertical, Spacing.xxs)
                            }
                            TransactionRow(transaction: tx)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                showingNewTransactionSheet = true
            } label: {
                Label("New Transaction", systemImage: "plus.circle")
                    .font(.shillingBody)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.shillingAccent)

            Button {
                showingImportSheet = true
            } label: {
                Label("Import CSV", systemImage: "square.and.arrow.down")
                    .font(.shillingBody)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.shillingAccent)

            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadBudget() {
        let service = BudgetService(context: context)
        do {
            budgetComparisons = try service.monthlySummary(year: currentYear, month: currentMonth)
        } catch {
            budgetComparisons = []
        }
    }
}

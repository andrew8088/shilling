import Charts
import SwiftUI
import SwiftData
import ShillingCore

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Binding var selection: NavigationItem?

    @Query(sort: \Account.name) private var allAccounts: [Account]
    @Query(sort: \Txn.date, order: .reverse) private var allTransactions: [Txn]

    @State private var budgetComparisons: [BudgetComparison] = []
    @State private var showingNewAccountSheet = false
    @State private var showingNewTransactionSheet = false
    @State private var showingImportSheet = false
    @State private var cardsVisible = false
    @State private var netWorthSnapshots: [MonthSnapshot] = []

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var currentMonth: Int { Calendar.current.component(.month, from: Date()) }

    var body: some View {
        ScrollView {
            if activeAccounts.isEmpty {
                EmptyStateView(
                    icon: "building.columns",
                    title: "No Accounts Yet",
                    message: "Create your first account to start tracking balances, transactions, and budgets.",
                    actions: [
                        .init("Create Account", systemImage: "plus", isPrimary: true) {
                            showingNewAccountSheet = true
                        }
                    ]
                )
                .padding(Spacing.xl)
                .onAppear { cardsVisible = false }
            } else if allTransactions.isEmpty && budgetComparisons.isEmpty {
                EmptyStateView(
                    icon: "sparkles",
                    title: "Welcome to Your Dashboard",
                    message: "Next step: add your first transaction or import a CSV statement to populate charts and summaries.",
                    actions: [
                        .init("Create Transaction", systemImage: "plus.circle", isPrimary: true) {
                            showingNewTransactionSheet = true
                        },
                        .init("Import CSV", systemImage: "square.and.arrow.down") {
                            showingImportSheet = true
                        }
                    ]
                )
                .padding(Spacing.xl)
                .onAppear { cardsVisible = false }
            } else {
                VStack(spacing: ShillingLayout.sectionSpacing) {
                    netWorthCard
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 8)
                        .animation(.easeOut(duration: 0.22).delay(0.02), value: cardsVisible)
                    accountSummarySection
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 8)
                        .animation(.easeOut(duration: 0.24).delay(0.05), value: cardsVisible)
                    budgetSummaryCard
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 8)
                        .animation(.easeOut(duration: 0.26).delay(0.08), value: cardsVisible)
                    recentTransactionsSection
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 8)
                        .animation(.easeOut(duration: 0.28).delay(0.11), value: cardsVisible)
                    quickActions
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 8)
                        .animation(.easeOut(duration: 0.30).delay(0.14), value: cardsVisible)
                }
                .padding(Spacing.xl)
                .onAppear {
                    cardsVisible = true
                }
            }
        }
        .background(Color.shillingBackground)
        .navigationTitle("Dashboard")
        .task { loadDashboardData() }
        .sheet(isPresented: $showingNewAccountSheet) {
            AccountFormSheet(account: nil)
        }
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

    private var netWorthTrendPoints: [(date: Date, value: Double)] {
        netWorthSnapshots.map { snapshot in
            (date: snapshot.date, value: NSDecimalNumber(decimal: snapshot.netWorth).doubleValue)
        }
    }

    private var netWorthTrendYDomain: ClosedRange<Double> {
        let values = netWorthTrendPoints.map(\.value)
        guard let minValue = values.min(), let maxValue = values.max() else {
            return -1...1
        }

        if minValue == maxValue {
            let baseline = abs(maxValue)
            let padding = Swift.max(1, baseline * 0.1)
            return (minValue - padding)...(maxValue + padding)
        }

        let padding = (maxValue - minValue) * 0.2
        return (minValue - padding)...(maxValue + padding)
    }

    private var netWorthCard: some View {
        CardView {
            ZStack {
                netWorthTrendBackground
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
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var netWorthTrendBackground: some View {
        if netWorthTrendPoints.count >= 2 {
            Chart {
                ForEach(Array(netWorthTrendPoints.enumerated()), id: \.offset) { _, point in
                    AreaMark(
                        x: .value("Month", point.date),
                        y: .value("Net Worth", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                ChartColorScheme.balance.opacity(0.16),
                                ChartColorScheme.balance.opacity(0.03),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Month", point.date),
                        y: .value("Net Worth", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(ChartColorScheme.balance.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }

                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.shillingBorder.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 0.75, dash: [2, 3]))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: netWorthTrendYDomain)
            .chartPlotStyle { plotArea in
                plotArea.background(.clear)
            }
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .mask(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.85), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Account Summary

    private var accountTypeGroups: [(type: AccountType, accounts: [Account], total: Decimal)] {
        let service = BalanceService(context: context)
        return [AccountType.asset, .liability, .income, .expense]
            .compactMap { type in
                let accounts = activeAccounts.filter { $0.type == type && $0.parent == nil }
                guard !accounts.isEmpty else { return nil }
                let total = accounts.reduce(Decimal.zero) { $0 + service.rollupBalance(for: $1) }
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
                    VStack(spacing: Spacing.sm) {
                        Text("No transactions yet")
                            .font(.shillingBody)
                            .foregroundStyle(Color.shillingTextSecondary)
                            .frame(maxWidth: .infinity)

                        HStack(spacing: Spacing.sm) {
                            Button("Create Transaction") {
                                showingNewTransactionSheet = true
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Import CSV") {
                                showingImportSheet = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
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

    private func loadDashboardData() {
        loadBudget()
        loadNetWorthHistory()
    }

    private func loadBudget() {
        let service = BudgetService(context: context)
        do {
            budgetComparisons = try service.monthlySummary(year: currentYear, month: currentMonth)
        } catch {
            budgetComparisons = []
        }
    }

    private func loadNetWorthHistory() {
        let service = ReportService(context: context)
        do {
            netWorthSnapshots = try service.netWorthHistory(months: 12)
        } catch {
            netWorthSnapshots = []
        }
    }
}

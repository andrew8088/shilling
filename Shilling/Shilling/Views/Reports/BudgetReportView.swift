import Charts
import SwiftUI
import ShillingCore

struct BudgetReportView: View {
    @Environment(\.modelContext) private var context

    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var month: Int = Calendar.current.component(.month, from: Date())
    @State private var comparisons: [BudgetComparison] = []

    private var totalBudgeted: Decimal { comparisons.reduce(.zero) { $0 + $1.budgetAmount } }
    private var totalSpent: Decimal { comparisons.reduce(.zero) { $0 + $1.actualAmount } }
    private var totalRemaining: Decimal { totalBudgeted - totalSpent }

    var body: some View {
        VStack(spacing: 0) {
            monthPicker
            Divider()
            content
        }
        .task { loadData() }
        .onChange(of: year) { loadData() }
        .onChange(of: month) { loadData() }
    }

    // MARK: - Month Picker

    private var monthPicker: some View {
        HStack {
            Button {
                adjustMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Text(FormatHelpers.monthYear(year: year, month: month))
                .font(.shillingTitle)
                .frame(minWidth: 150)

            Button {
                adjustMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
        }
        .padding()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if comparisons.isEmpty {
            EmptyStateView(
                icon: "chart.bar",
                title: "No Budget Targets",
                message: "Set budget targets in the Budget view to see comparisons here.",
                actions: [
                    .init("Go to Current Month", systemImage: "calendar") {
                        year = Calendar.current.component(.year, from: Date())
                        month = Calendar.current.component(.month, from: Date())
                    }
                ]
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: ShillingLayout.sectionSpacing) {
                    summaryCards
                    chartSection
                }
                .padding(Spacing.xl)
            }
            .background(Color.shillingBackground)
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: Spacing.sm) {
            CardView {
                VStack(spacing: Spacing.xxs) {
                    Text("Budgeted")
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingTextSecondary)
                    AmountText(totalBudgeted, font: .shillingAmountMono)
                }
                .frame(maxWidth: .infinity)
            }

            CardView {
                VStack(spacing: Spacing.xxs) {
                    Text("Net Spend")
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingTextSecondary)
                    AmountText(-totalSpent, font: .shillingAmountMono)
                }
                .frame(maxWidth: .infinity)
            }

            CardView {
                VStack(spacing: Spacing.xxs) {
                    Text("Remaining")
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingTextSecondary)
                    AmountText(totalRemaining, font: .shillingAmountMono)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        ChartCard("Budget vs Actual by Category", height: CGFloat(max(200, comparisons.count * 48))) {
            Chart(comparisons, id: \.account.id) { comparison in
                let budgetVal = NSDecimalNumber(decimal: comparison.budgetAmount).doubleValue
                let actualVal = NSDecimalNumber(decimal: comparison.actualAmount).doubleValue

                BarMark(
                    x: .value("Amount", actualVal),
                    y: .value("Category", comparison.account.name)
                )
                .foregroundStyle(actualVal > budgetVal ? ChartColorScheme.expense : ChartColorScheme.income)

                RuleMark(x: .value("Budget", budgetVal))
                    .foregroundStyle(ChartColorScheme.budget)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .annotation(position: .trailing, spacing: 4) {
                        Text(FormatHelpers.currency(comparison.budgetAmount))
                            .font(.system(size: 9))
                            .foregroundStyle(Color.shillingTextTertiary)
                    }
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(FormatHelpers.currency(Decimal(amount)))
                                .font(.shillingCaption)
                        }
                    }
                }
            }
            .chartLegend(position: .bottom) {
                HStack(spacing: Spacing.md) {
                    legendItem("Actual", color: ChartColorScheme.income)
                    legendItem("Over Budget", color: ChartColorScheme.expense)
                    legendItem("Target", color: ChartColorScheme.budget)
                }
            }
        }
    }

    private func legendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: Spacing.xxs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.shillingCaption)
                .foregroundStyle(Color.shillingTextSecondary)
        }
    }

    // MARK: - Helpers

    private func adjustMonth(by delta: Int) {
        var m = month + delta
        var y = year
        if m < 1 { m = 12; y -= 1 }
        if m > 12 { m = 1; y += 1 }
        month = m
        year = y
    }

    private func loadData() {
        let service = BudgetService(context: context)
        do {
            comparisons = try service.monthlySummary(year: year, month: month)
        } catch {
            comparisons = []
        }
    }
}

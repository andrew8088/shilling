import Charts
import SwiftUI
import ShillingCore

struct CashFlowReportView: View {
    @Environment(\.modelContext) private var context

    enum Period: String, CaseIterable, Identifiable {
        case sixMonths = "6M"
        case oneYear = "1Y"
        case twoYears = "2Y"

        var id: String { rawValue }
        var months: Int {
            switch self {
            case .sixMonths: return 6
            case .oneYear: return 12
            case .twoYears: return 24
            }
        }
    }

    @State private var period: Period = .oneYear
    @State private var data: [CashFlowMonth] = []

    private var totalIncome: Decimal { data.reduce(.zero) { $0 + $1.income } }
    private var totalExpenses: Decimal { data.reduce(.zero) { $0 + $1.expenses } }
    private var totalNet: Decimal { totalIncome - totalExpenses }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShillingLayout.sectionSpacing) {
                periodPicker
                summaryCards
                chartSection
            }
            .padding(Spacing.xl)
        }
        .background(Color.shillingBackground)
        .task { loadData() }
        .onChange(of: period) { loadData() }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $period) {
            ForEach(Period.allCases) { p in
                Text(p.rawValue).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: Spacing.sm) {
            CardView {
                VStack(spacing: Spacing.xxs) {
                    Text("Total Income")
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingTextSecondary)
                    AmountText(totalIncome, font: .shillingAmountMono)
                }
                .frame(maxWidth: .infinity)
            }

            CardView {
                VStack(spacing: Spacing.xxs) {
                    Text("Total Expenses")
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingTextSecondary)
                    Text(FormatHelpers.currency(totalExpenses))
                        .font(.shillingAmountMono)
                        .foregroundStyle(Color.shillingNegative)
                }
                .frame(maxWidth: .infinity)
            }

            CardView {
                VStack(spacing: Spacing.xxs) {
                    Text("Net Cash Flow")
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingTextSecondary)
                    AmountText(totalNet, font: .shillingAmountMono)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        ChartCard("Income vs Expenses", height: 280) {
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { _, month in
                    BarMark(
                        x: .value("Month", month.date),
                        y: .value("Amount", NSDecimalNumber(decimal: month.income).doubleValue)
                    )
                    .foregroundStyle(ChartColorScheme.income)
                    .position(by: .value("Type", "Income"))

                    BarMark(
                        x: .value("Month", month.date),
                        y: .value("Amount", NSDecimalNumber(decimal: month.expenses).doubleValue)
                    )
                    .foregroundStyle(ChartColorScheme.expense)
                    .position(by: .value("Type", "Expenses"))
                }

                ForEach(Array(data.enumerated()), id: \.offset) { _, month in
                    LineMark(
                        x: .value("Month", month.date),
                        y: .value("Net", NSDecimalNumber(decimal: month.net).doubleValue)
                    )
                    .foregroundStyle(ChartColorScheme.balance)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(FormatHelpers.currency(Decimal(amount)))
                                .font(.shillingCaption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartLegend(position: .bottom) {
                HStack(spacing: Spacing.md) {
                    legendItem("Income", color: ChartColorScheme.income)
                    legendItem("Expenses", color: ChartColorScheme.expense)
                    legendItem("Net", color: ChartColorScheme.balance)
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

    // MARK: - Data

    private func loadData() {
        let service = ReportService(context: context)
        do {
            data = try service.cashFlow(months: period.months)
        } catch {
            data = []
        }
    }
}

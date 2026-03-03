import Charts
import SwiftUI
import ShillingCore

struct NetWorthReportView: View {
    @Environment(\.modelContext) private var context

    enum Period: String, CaseIterable, Identifiable {
        case sixMonths = "6M"
        case oneYear = "1Y"
        case twoYears = "2Y"
        case all = "All"

        var id: String { rawValue }
        var months: Int {
            switch self {
            case .sixMonths: return 6
            case .oneYear: return 12
            case .twoYears: return 24
            case .all: return 120
            }
        }
    }

    @State private var period: Period = .oneYear
    @State private var snapshots: [MonthSnapshot] = []

    private var currentNetWorth: Decimal {
        snapshots.last?.netWorth ?? .zero
    }

    private var periodChange: Decimal {
        guard let first = snapshots.first, let last = snapshots.last else { return .zero }
        return last.netWorth - first.netWorth
    }

    private var periodChangePercent: Double {
        guard let first = snapshots.first, first.netWorth != .zero else { return 0 }
        return NSDecimalNumber(decimal: periodChange / first.netWorth * 100).doubleValue
    }

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
        .frame(maxWidth: 300)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: Spacing.sm) {
            CardView {
                VStack(spacing: Spacing.xxs) {
                    Text("Net Worth")
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingTextSecondary)
                    AmountText(currentNetWorth, font: .shillingAmountMono)
                }
                .frame(maxWidth: .infinity)
            }

            CardView {
                VStack(spacing: Spacing.xxs) {
                    Text("Change")
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingTextSecondary)
                    AmountText(periodChange, font: .shillingAmountMono)
                }
                .frame(maxWidth: .infinity)
            }

            CardView {
                VStack(spacing: Spacing.xxs) {
                    Text("% Change")
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingTextSecondary)
                    Text(String(format: "%+.1f%%", periodChangePercent))
                        .font(.shillingAmountMono)
                        .foregroundStyle(periodChange >= 0 ? Color.shillingPositive : Color.shillingNegative)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        ChartCard("Net Worth Over Time", height: 280) {
            Chart {
                ForEach(Array(snapshots.enumerated()), id: \.offset) { _, snapshot in
                    AreaMark(
                        x: .value("Month", snapshot.date),
                        y: .value("Net Worth", NSDecimalNumber(decimal: snapshot.netWorth).doubleValue)
                    )
                    .foregroundStyle(ChartColorScheme.balance.opacity(0.1))

                    LineMark(
                        x: .value("Month", snapshot.date),
                        y: .value("Net Worth", NSDecimalNumber(decimal: snapshot.netWorth).doubleValue)
                    )
                    .foregroundStyle(ChartColorScheme.balance)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    LineMark(
                        x: .value("Month", snapshot.date),
                        y: .value("Assets", NSDecimalNumber(decimal: snapshot.assets).doubleValue)
                    )
                    .foregroundStyle(ChartColorScheme.income)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                    LineMark(
                        x: .value("Month", snapshot.date),
                        y: .value("Liabilities", NSDecimalNumber(decimal: snapshot.liabilities).doubleValue)
                    )
                    .foregroundStyle(ChartColorScheme.expense)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
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
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartLegend(position: .bottom) {
                HStack(spacing: Spacing.md) {
                    legendItem("Net Worth", color: ChartColorScheme.balance)
                    legendItem("Assets", color: ChartColorScheme.income)
                    legendItem("Liabilities", color: ChartColorScheme.expense)
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
            snapshots = try service.netWorthHistory(months: period.months)
        } catch {
            snapshots = []
        }
    }
}

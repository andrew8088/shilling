import Charts
import SwiftUI

// MARK: - ChartColorScheme

enum ChartColorScheme {
    /// Color for income / positive values
    static let income: Color = .shillingPositive
    /// Color for expense / negative values
    static let expense: Color = .shillingNegative
    /// Color for neutral / informational series
    static let neutral: Color = .shillingInfo
    /// Color for budget target lines
    static let budget: Color = .shillingWarning
    /// Color for net worth / balance
    static let balance: Color = .shillingAccent

    /// Ordered palette for multi-series charts (e.g., category breakdowns)
    static let palette: [Color] = [
        .shillingAccent,
        .shillingPositive,
        .shillingWarning,
        .shillingNegative,
        .shillingInfo,
    ]
}

// MARK: - ChartCard

struct ChartCard<Chart: View>: View {
    let title: String
    let subtitle: String?
    let height: CGFloat
    @ViewBuilder let chart: () -> Chart

    init(
        _ title: String,
        subtitle: String? = nil,
        height: CGFloat = 200,
        @ViewBuilder chart: @escaping () -> Chart
    ) {
        self.title = title
        self.subtitle = subtitle
        self.height = height
        self.chart = chart
    }

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(title, subtitle: subtitle)
                chart()
                    .frame(height: height)
            }
        }
    }
}

// MARK: - Previews

#Preview("ChartCard") {
    // Sample data for previews
    let monthlyData: [(String, Double, Double)] = [
        ("Jan", 3200, 2800),
        ("Feb", 3200, 3100),
        ("Mar", 3200, 2400),
        ("Apr", 3200, 3500),
    ]

    let netWorthData: [(String, Double)] = [
        ("Jan", 45000),
        ("Feb", 46200),
        ("Mar", 47800),
        ("Apr", 46500),
    ]

    ScrollView {
        VStack(spacing: Spacing.xl) {
            // Bar chart: income vs expenses
            ChartCard("Income vs Expenses", subtitle: "2026") {
                Chart {
                    ForEach(monthlyData, id: \.0) { month, income, expenses in
                        BarMark(
                            x: .value("Month", month),
                            y: .value("Amount", income)
                        )
                        .foregroundStyle(ChartColorScheme.income)
                        .position(by: .value("Type", "Income"))

                        BarMark(
                            x: .value("Month", month),
                            y: .value("Amount", expenses)
                        )
                        .foregroundStyle(ChartColorScheme.expense)
                        .position(by: .value("Type", "Expenses"))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }

            // Line chart: net worth
            ChartCard("Net Worth", subtitle: "Trend", height: 180) {
                Chart {
                    ForEach(netWorthData, id: \.0) { month, value in
                        LineMark(
                            x: .value("Month", month),
                            y: .value("Net Worth", value)
                        )
                        .foregroundStyle(ChartColorScheme.balance)

                        AreaMark(
                            x: .value("Month", month),
                            y: .value("Net Worth", value)
                        )
                        .foregroundStyle(ChartColorScheme.balance.opacity(0.1))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding(Spacing.xl)
    }
    .background(Color.shillingBackground)
    .frame(width: 500, height: 600)
}

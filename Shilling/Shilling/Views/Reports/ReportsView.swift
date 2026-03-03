import SwiftUI

enum ReportType: String, CaseIterable, Identifiable {
    case netWorth = "Net Worth"
    case cashFlow = "Cash Flow"
    case budgetVsActual = "Budget vs Actual"
    case balanceSheet = "Balance Sheet"

    var id: String { rawValue }
}

struct ReportsView: View {
    @State private var selectedReport: ReportType = .netWorth

    var body: some View {
        VStack(spacing: 0) {
            Picker("Report", selection: $selectedReport) {
                ForEach(ReportType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(Spacing.md)

            Divider()

            reportView
        }
        .navigationTitle("Reports")
    }

    @ViewBuilder
    private var reportView: some View {
        switch selectedReport {
        case .netWorth:
            NetWorthReportView()
        case .cashFlow:
            CashFlowReportView()
        case .budgetVsActual:
            BudgetReportView()
        case .balanceSheet:
            BalanceSheetReportView()
        }
    }
}

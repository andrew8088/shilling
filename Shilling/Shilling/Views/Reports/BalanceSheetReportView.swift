import SwiftUI
import ShillingCore

struct BalanceSheetReportView: View {
    @Environment(\.modelContext) private var context

    @State private var asOfDate: Date = Date()
    @State private var sheetData: BalanceSheetData?

    var body: some View {
        VStack(spacing: 0) {
            datePicker
            Divider()
            content
        }
        .task { loadData() }
        .onChange(of: asOfDate) { loadData() }
    }

    // MARK: - Date Picker

    private var datePicker: some View {
        HStack {
            Text("As of")
                .font(.shillingBody)
                .foregroundStyle(Color.shillingTextSecondary)
            DatePicker("", selection: $asOfDate, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)
        }
        .padding()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let data = sheetData {
            if data.assets.isEmpty && data.liabilities.isEmpty && data.equity.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Balances",
                    message: "No accounts have balances as of this date."
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: ShillingLayout.sectionSpacing) {
                        netWorthCard(data)
                        if !data.assets.isEmpty { accountSection("Assets", accounts: data.assets, total: data.totalAssets) }
                        if !data.liabilities.isEmpty { accountSection("Liabilities", accounts: data.liabilities, total: data.totalLiabilities) }
                        if !data.equity.isEmpty { accountSection("Equity", accounts: data.equity, total: data.totalEquity) }
                    }
                    .padding(Spacing.xl)
                }
                .background(Color.shillingBackground)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Net Worth Card

    private func netWorthCard(_ data: BalanceSheetData) -> some View {
        CardView {
            VStack(spacing: Spacing.sm) {
                Text("Net Worth")
                    .font(.shillingCaption)
                    .foregroundStyle(Color.shillingTextSecondary)
                AmountText(data.netWorth, font: .shillingLargeTitleMono)
                HStack(spacing: Spacing.lg) {
                    VStack(spacing: Spacing.xxs) {
                        Text("Assets")
                            .font(.shillingCaption)
                            .foregroundStyle(Color.shillingTextTertiary)
                        Text(FormatHelpers.currency(data.totalAssets))
                            .font(.shillingBodyMono)
                            .foregroundStyle(Color.shillingTextSecondary)
                    }
                    VStack(spacing: Spacing.xxs) {
                        Text("Liabilities")
                            .font(.shillingCaption)
                            .foregroundStyle(Color.shillingTextTertiary)
                        Text(FormatHelpers.currency(data.totalLiabilities))
                            .font(.shillingBodyMono)
                            .foregroundStyle(Color.shillingTextSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Account Section

    private func accountSection(_ title: String, accounts: [(account: Account, balance: Decimal)], total: Decimal) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title, subtitle: FormatHelpers.currency(total))

            CardView {
                VStack(spacing: 0) {
                    ForEach(Array(accounts.enumerated()), id: \.element.account.id) { index, item in
                        if index > 0 {
                            Divider().padding(.vertical, Spacing.xxs)
                        }
                        HStack {
                            Text(item.account.name)
                                .font(.shillingBody)
                                .foregroundStyle(Color.shillingTextPrimary)
                            Spacer()
                            AmountText(item.balance, font: .shillingBodyMono)
                        }
                    }

                    Divider().padding(.vertical, Spacing.xs)

                    HStack {
                        Text("Total \(title)")
                            .font(.shillingSubheading)
                            .foregroundStyle(Color.shillingTextPrimary)
                        Spacer()
                        Text(FormatHelpers.currency(total))
                            .font(.shillingAmountMono)
                            .foregroundStyle(Color.shillingTextPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Data

    private func loadData() {
        let service = ReportService(context: context)
        do {
            sheetData = try service.balanceSheet(asOf: asOfDate)
        } catch {
            sheetData = nil
        }
    }
}

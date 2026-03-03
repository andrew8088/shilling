import SwiftUI
import SwiftData
import ShillingCore

struct BudgetView: View {
    @Environment(\.modelContext) private var context

    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var month: Int = Calendar.current.component(.month, from: Date())
    @State private var comparisons: [BudgetComparison] = []
    @State private var showingTargetSheet = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            monthPicker
            Divider()
            budgetContent
        }
        .navigationTitle("Budget")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingTargetSheet = true
                } label: {
                    Label("Set Target", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button("Copy Previous") { copyFromPreviousMonth() }
                    .help("Copy budget targets from the previous month")
            }
        }
        .sheet(isPresented: $showingTargetSheet, onDismiss: { loadSummary() }) {
            BudgetTargetSheet(year: year, month: month)
        }
        .task { loadSummary() }
        .onChange(of: year) { loadSummary() }
        .onChange(of: month) { loadSummary() }
    }

    @ViewBuilder
    private var budgetContent: some View {
        if comparisons.isEmpty {
            EmptyStateView(
                icon: "chart.bar",
                title: "No Budget Targets",
                message: "Set budget targets for expense accounts to track spending."
            )
        } else {
            List(comparisons, id: \.account.id) { row in
                BudgetRow(comparison: row)
            }
        }
    }

    private var monthPicker: some View {
        HStack {
            Button {
                adjustMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Text(FormatHelpers.monthYear(year: year, month: month))
                .font(.title3)
                .fontWeight(.medium)
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

    private func adjustMonth(by delta: Int) {
        var m = month + delta
        var y = year
        if m < 1 { m = 12; y -= 1 }
        if m > 12 { m = 1; y += 1 }
        month = m
        year = y
    }

    private func loadSummary() {
        let service = BudgetService(context: context)
        do {
            comparisons = try service.monthlySummary(year: year, month: month)
        } catch {
            comparisons = []
        }
    }

    private func copyFromPreviousMonth() {
        var prevMonth = month - 1
        var prevYear = year
        if prevMonth < 1 { prevMonth = 12; prevYear -= 1 }

        let service = BudgetService(context: context)
        do {
            let previous = try service.monthlySummary(year: prevYear, month: prevMonth)
            for comp in previous {
                try service.setBudget(
                    account: comp.account,
                    year: year,
                    month: month,
                    amount: comp.budgetAmount
                )
            }
            try context.save()
            loadSummary()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remainingColor(_ comparison: BudgetComparison) -> Color {
        guard comparison.budgetAmount > 0 else { return .primary }
        let ratio = comparison.remaining / comparison.budgetAmount
        if ratio < 0 { return .red }
        if ratio <= Decimal(string: "0.2")! { return .yellow }
        return .green
    }
}

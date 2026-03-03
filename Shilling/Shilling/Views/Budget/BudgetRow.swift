import SwiftUI
import ShillingCore

struct BudgetRow: View {
    let comparison: BudgetComparison

    private var remainingColor: Color {
        guard comparison.budgetAmount > 0 else { return .primary }
        let ratio = comparison.remaining / comparison.budgetAmount
        if ratio < 0 { return .red }
        if ratio <= Decimal(string: "0.2")! { return .yellow }
        return .green
    }

    var body: some View {
        HStack {
            Text(comparison.account.name)
                .frame(minWidth: 120, alignment: .leading)
            Spacer()
            Text(FormatHelpers.currency(comparison.budgetAmount))
                .monospacedDigit()
                .frame(width: 90, alignment: .trailing)
            Text(FormatHelpers.currency(comparison.actualAmount))
                .monospacedDigit()
                .frame(width: 90, alignment: .trailing)
            Text(FormatHelpers.currency(comparison.remaining))
                .monospacedDigit()
                .foregroundStyle(remainingColor)
                .frame(width: 90, alignment: .trailing)
        }
    }
}

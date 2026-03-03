import SwiftUI
import ShillingCore

struct BudgetRow: View {
    let comparison: BudgetComparison

    private var progress: Double {
        guard comparison.budgetAmount > 0 else { return 0 }
        return NSDecimalNumber(decimal: comparison.actualAmount / comparison.budgetAmount).doubleValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(comparison.account.name)
                .font(.shillingSubheading)
                .foregroundStyle(Color.shillingTextPrimary)

            ProgressBar(value: progress)

            HStack {
                Text("\(FormatHelpers.currency(comparison.actualAmount)) of \(FormatHelpers.currency(comparison.budgetAmount))")
                    .font(.shillingCaption)
                    .foregroundStyle(Color.shillingTextSecondary)
                Spacer()
                AmountText(comparison.remaining, font: .shillingBodyMono)
            }
        }
    }
}

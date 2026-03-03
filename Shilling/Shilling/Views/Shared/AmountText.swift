import SwiftUI

// MARK: - AmountText
//
// Displays a Decimal amount formatted as currency with sign-based semantic coloring.
// Positive → green, negative → red, zero → secondary text.
// Always uses monospaced digits for alignment in lists and tables.

struct AmountText: View {
    let amount: Decimal
    let font: Font

    init(_ amount: Decimal, font: Font = .shillingBodyMono) {
        self.amount = amount
        self.font = font
    }

    private var color: Color {
        if amount > 0 {
            return .shillingPositive
        } else if amount < 0 {
            return .shillingNegative
        } else {
            return .shillingTextSecondary
        }
    }

    var body: some View {
        Text(FormatHelpers.currency(amount))
            .font(font)
            .foregroundStyle(color)
    }
}

// MARK: - Preview

#Preview("AmountText") {
    VStack(alignment: .trailing, spacing: Spacing.sm) {
        Group {
            Text("Body Mono (default)").font(.shillingCaption).foregroundStyle(Color.shillingTextSecondary)
            AmountText(Decimal(string: "1234.56")!)
            AmountText(Decimal(string: "-89.00")!)
            AmountText(Decimal(0))
        }

        Divider().padding(.vertical, Spacing.xxs)

        Group {
            Text("Amount Mono (larger)").font(.shillingCaption).foregroundStyle(Color.shillingTextSecondary)
            AmountText(Decimal(string: "42150.00")!, font: .shillingAmountMono)
            AmountText(Decimal(string: "-500.00")!, font: .shillingAmountMono)
            AmountText(Decimal(0), font: .shillingAmountMono)
        }

        Divider().padding(.vertical, Spacing.xxs)

        Group {
            Text("Large Title Mono (hero)").font(.shillingCaption).foregroundStyle(Color.shillingTextSecondary)
            AmountText(Decimal(string: "98765.43")!, font: .shillingLargeTitleMono)
            AmountText(Decimal(string: "-1200.00")!, font: .shillingLargeTitleMono)
        }
    }
    .padding(Spacing.xl)
    .background(Color.shillingBackground)
    .frame(width: 320)
}

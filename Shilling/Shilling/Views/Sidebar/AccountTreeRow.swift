import SwiftUI
import ShillingCore

struct AccountTreeRow: View {
    let account: Account
    @Environment(\.modelContext) private var context

    private var balance: Decimal {
        let service = BalanceService(context: context)
        return service.balance(for: account)
    }

    var body: some View {
        HStack {
            Text(account.name)
                .font(.shillingBody)
                .foregroundStyle(account.isArchived ? .secondary : .primary)
            if account.isArchived {
                Text("archived")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            Spacer()
            if #available(macOS 14.0, *) {
                AmountText(balance, font: .shillingCaption)
                    .contentTransition(.numericText(value: NSDecimalNumber(decimal: balance).doubleValue))
                    .animation(.easeInOut(duration: 0.2), value: balance)
            } else {
                AmountText(balance, font: .shillingCaption)
            }
        }
    }
}

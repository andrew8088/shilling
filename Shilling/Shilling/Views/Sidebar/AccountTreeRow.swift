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
            Text(FormatHelpers.currency(balance))
                .font(.body.monospacedDigit())
                .foregroundStyle(balance < 0 ? .red : .secondary)
        }
    }
}

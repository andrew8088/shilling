import SwiftUI
import ShillingCore

struct TransactionRow: View {
    let transaction: Txn

    private var totalAmount: Decimal {
        transaction.entries
            .filter { $0.type == .debit }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var accountSummary: String {
        let accounts = Set(transaction.entries.compactMap { $0.account?.name })
        return accounts.sorted().joined(separator: ", ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.payee)
                    .fontWeight(.medium)
                Text(accountSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(FormatHelpers.currency(totalAmount))
                    .monospacedDigit()
                Text(FormatHelpers.date(transaction.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

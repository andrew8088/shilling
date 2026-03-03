import SwiftUI
import SwiftData
import ShillingCore

struct OpeningBalanceSheet: View {
    let account: Account
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Decimal = .zero
    @State private var date: Date = Date()
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    HStack {
                        Text("Account")
                        Spacer()
                        Text(account.name)
                            .foregroundStyle(.secondary)
                    }
                    CurrencyField(label: "Amount", amount: $amount)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(amount <= 0)
            }
            .padding()
        }
        .frame(minWidth: 350, minHeight: 200)
    }

    private func save() {
        errorMessage = nil
        do {
            let txService = TransactionService(context: context)
            let allAccounts = try context.fetch(FetchDescriptor<Account>())
            guard let obAccount = allAccounts.first(where: { $0.name == "Opening Balances" && $0.type == .equity }) else {
                errorMessage = "Opening Balances account not found. Please seed the database first."
                return
            }
            try txService.createOpeningBalance(
                account: account,
                amount: amount,
                date: date,
                openingBalancesAccount: obAccount
            )
            try context.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

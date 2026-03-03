import SwiftUI
import SwiftData
import ShillingCore

struct BudgetTargetSheet: View {
    let year: Int
    let month: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var account: Account? = nil
    @State private var amount: Decimal = .zero
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    AccountPicker(
                        label: "Account",
                        selection: $account,
                        filter: { $0.type == .expense }
                    )
                    CurrencyField(label: "Monthly Target", amount: $amount)
                    HStack {
                        Text("Period")
                        Spacer()
                        Text(FormatHelpers.monthYear(year: year, month: month))
                            .foregroundStyle(.secondary)
                    }
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
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(account == nil || amount <= 0)
            }
            .padding()
        }
        .frame(minWidth: 350, minHeight: 200)
    }

    private func save() {
        guard let account else { return }
        errorMessage = nil

        let service = BudgetService(context: context)
        do {
            try service.setBudget(account: account, year: year, month: month, amount: amount)
            try context.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

import SwiftUI
import SwiftData
import ShillingCore

struct AccountFormSheet: View {
    let account: Account?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var accountType: AccountType = .expense
    @State private var parent: Account? = nil
    @State private var notes: String = ""
    @State private var errorMessage: String? = nil

    // Opening balance (create only)
    @State private var includeOpeningBalance = false
    @State private var openingBalanceAmount: Decimal = .zero
    @State private var openingBalanceDate: Date = Date()

    private var isEditing: Bool { account != nil }
    private var title: String { isEditing ? "Edit Account" : "New Account" }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $name)
                    if !isEditing {
                        Picker("Type", selection: $accountType) {
                            ForEach(AccountType.allCases, id: \.self) { type in
                                Text(type.rawValue.capitalized).tag(type)
                            }
                        }
                    }
                    AccountPicker(label: "Parent", selection: $parent, filter: { $0.type == accountType })
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }

                if !isEditing {
                    Section {
                        Toggle("Set Opening Balance", isOn: $includeOpeningBalance)
                        if includeOpeningBalance {
                            CurrencyField(label: "Amount", amount: $openingBalanceAmount)
                            DatePicker("Date", selection: $openingBalanceDate, displayedComponents: .date)
                        }
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
                Button(isEditing ? "Save" : "Create") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            if let account {
                name = account.name
                accountType = account.type
                parent = account.parent
                notes = account.notes ?? ""
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let accountService = AccountService(context: context)
        errorMessage = nil

        do {
            if let account {
                try accountService.update(
                    account: account,
                    name: trimmedName,
                    type: account.type,
                    parent: parent,
                    isArchived: account.isArchived,
                    notes: notes.isEmpty ? nil : notes
                )
            } else {
                let newAccount = try accountService.create(
                    name: trimmedName,
                    type: accountType,
                    parent: parent,
                    notes: notes.isEmpty ? nil : notes
                )

                if includeOpeningBalance && openingBalanceAmount > 0 {
                    let txService = TransactionService(context: context)
                    let allAccounts = try context.fetch(FetchDescriptor<Account>())
                    if let obAccount = allAccounts.first(where: { $0.name == "Opening Balances" && $0.type == .equity }) {
                        try txService.createOpeningBalance(
                            account: newAccount,
                            amount: openingBalanceAmount,
                            date: openingBalanceDate,
                            openingBalancesAccount: obAccount
                        )
                    }
                }
            }
            try context.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

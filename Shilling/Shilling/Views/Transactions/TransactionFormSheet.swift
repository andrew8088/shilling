import SwiftUI
import SwiftData
import ShillingCore

struct TransactionFormSheet: View {
    let transaction: Txn?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = Date()
    @State private var payee: String = ""
    @State private var notes: String = ""
    @State private var useSimpleMode = true
    @State private var errorMessage: String? = nil

    // Simple mode
    @State private var fromAccount: Account? = nil
    @State private var toAccount: Account? = nil
    @State private var simpleAmount: Decimal = .zero

    // Split mode
    @State private var splitEntries: [SplitEntryRow] = [
        SplitEntryRow(),
        SplitEntryRow(),
    ]

    private var isEditing: Bool { transaction != nil }
    private var title: String { isEditing ? "Edit Transaction" : "New Transaction" }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Transaction") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Payee", text: $payee)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2)
                }

                Section {
                    Picker("Mode", selection: $useSimpleMode) {
                        Text("Simple").tag(true)
                        Text("Split").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                if useSimpleMode {
                    SimpleEntryForm(
                        fromAccount: $fromAccount,
                        toAccount: $toAccount,
                        amount: $simpleAmount
                    )
                } else {
                    SplitEntryForm(entries: $splitEntries)
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
                if isEditing {
                    Button("Delete", role: .destructive) { deleteTransaction() }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save" : "Create") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(payee.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear { loadTransaction() }
    }

    private func loadTransaction() {
        guard let transaction else { return }
        date = transaction.date
        payee = transaction.payee
        notes = transaction.notes ?? ""

        let entries = transaction.entries
        // If it's a simple 2-entry transaction, load into simple mode
        if entries.count == 2,
           let debitEntry = entries.first(where: { $0.type == .debit }),
           let creditEntry = entries.first(where: { $0.type == .credit }),
           debitEntry.amount == creditEntry.amount {
            useSimpleMode = true
            toAccount = debitEntry.account
            fromAccount = creditEntry.account
            simpleAmount = debitEntry.amount
        } else {
            useSimpleMode = false
            splitEntries = entries.map { entry in
                SplitEntryRow(
                    account: entry.account,
                    amount: entry.amount,
                    type: entry.type,
                    memo: entry.memo ?? ""
                )
            }
        }
    }

    private func buildEntryData() -> [EntryData]? {
        if useSimpleMode {
            guard let fromAccount, let toAccount, simpleAmount > 0 else { return nil }
            return [
                EntryData(account: toAccount, amount: simpleAmount, type: .debit),
                EntryData(account: fromAccount, amount: simpleAmount, type: .credit),
            ]
        } else {
            let data = splitEntries.compactMap { row -> EntryData? in
                guard let account = row.account, row.amount > 0 else { return nil }
                return EntryData(account: account, amount: row.amount, type: row.type, memo: row.memo.isEmpty ? nil : row.memo)
            }
            return data.count >= 2 ? data : nil
        }
    }

    private func save() {
        errorMessage = nil
        guard let entryData = buildEntryData() else {
            errorMessage = useSimpleMode
                ? "Select both accounts and enter an amount."
                : "Add at least two entries with accounts and amounts."
            return
        }

        let txService = TransactionService(context: context)
        let trimmedPayee = payee.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        do {
            if let transaction {
                try txService.updateTransaction(
                    transaction,
                    date: date,
                    payee: trimmedPayee,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    entries: entryData
                )
            } else {
                try txService.createTransaction(
                    date: date,
                    payee: trimmedPayee,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    entries: entryData
                )
            }
            try context.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteTransaction() {
        guard let transaction else { return }
        TransactionService(context: context).deleteTransaction(transaction)
        try? context.save()
        dismiss()
    }
}

import SwiftUI
import ShillingCore

struct SplitEntryRow: Identifiable {
    let id = UUID()
    var account: Account? = nil
    var amount: Decimal = .zero
    var type: EntryType = .debit
    var memo: String = ""
}

struct SplitEntryForm: View {
    @Binding var entries: [SplitEntryRow]

    private var debitTotal: Decimal {
        entries.filter { $0.type == .debit }.reduce(.zero) { $0 + $1.amount }
    }

    private var creditTotal: Decimal {
        entries.filter { $0.type == .credit }.reduce(.zero) { $0 + $1.amount }
    }

    private var isBalanced: Bool { debitTotal == creditTotal && debitTotal > 0 }

    var body: some View {
        Section("Entries") {
            ForEach($entries) { $entry in
                VStack(spacing: 6) {
                    HStack {
                        AccountPicker(label: "Account", selection: $entry.account)
                        Picker("Type", selection: $entry.type) {
                            Text("Debit").tag(EntryType.debit)
                            Text("Credit").tag(EntryType.credit)
                        }
                        .frame(width: 100)
                    }
                    HStack {
                        CurrencyField(label: "Amount", amount: $entry.amount)
                        TextField("Memo", text: $entry.memo)
                        Button {
                            entries.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(entries.count <= 2)
                    }
                }
                .padding(.vertical, 4)
            }

            Button {
                entries.append(SplitEntryRow())
            } label: {
                Label("Add Entry", systemImage: "plus")
            }
        }

        Section {
            HStack {
                Text("Debits: \(FormatHelpers.currency(debitTotal))")
                Spacer()
                Text("Credits: \(FormatHelpers.currency(creditTotal))")
                Spacer()
                if isBalanced {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("Unbalanced")
                        .foregroundStyle(.red)
                }
            }
            .font(.callout.monospacedDigit())
        }
    }
}

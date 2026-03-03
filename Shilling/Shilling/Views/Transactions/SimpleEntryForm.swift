import SwiftUI
import ShillingCore

struct SimpleEntryForm: View {
    @Binding var fromAccount: Account?
    @Binding var toAccount: Account?
    @Binding var amount: Decimal

    var body: some View {
        Section("Entries") {
            AccountPicker(label: "From (Credit)", selection: $fromAccount)
            AccountPicker(label: "To (Debit)", selection: $toAccount)
            CurrencyField(label: "Amount", amount: $amount)
        }
    }
}

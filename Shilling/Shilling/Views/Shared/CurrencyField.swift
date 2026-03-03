import SwiftUI

struct CurrencyField: View {
    let label: String
    @Binding var amount: Decimal

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(label, text: $text)
            .focused($isFocused)
            .onAppear {
                text = amount == .zero ? "" : formatForEditing(amount)
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    parseAndUpdate()
                }
            }
            .onSubmit {
                parseAndUpdate()
            }
    }

    private func parseAndUpdate() {
        let cleaned = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        if cleaned.isEmpty {
            amount = .zero
            text = ""
        } else if let value = Decimal(string: cleaned) {
            amount = value
            text = formatForEditing(value)
        }
    }

    private func formatForEditing(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}

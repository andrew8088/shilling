import Foundation

// MARK: - AmountParser

/// Parses monetary amount strings into `Decimal` values.
///
/// Handles:
/// - Signed values: "-45.99", "+100.00", "100.00"
/// - Currency symbols: "$", "€", "£" (and their negative counterparts)
/// - Thousand separators: "1,234.56"
/// - Parenthetical negatives common in accounting exports: "(45.99)"
public struct AmountParser {

    // MARK: Public API

    /// Parse a monetary string into a `Decimal`.
    ///
    /// Returns `nil` if the string cannot be interpreted as a valid amount.
    public static func parse(_ string: String) -> Decimal? {
        var s = string.trimmingCharacters(in: .whitespaces)

        guard !s.isEmpty else { return nil }

        // Detect and strip parenthetical negative: (45.99) → -45.99
        var isNegative = false
        if s.hasPrefix("(") && s.hasSuffix(")") {
            isNegative = true
            s = String(s.dropFirst().dropLast())
        }

        // Strip leading minus or plus
        if s.hasPrefix("-") {
            isNegative = true
            s = String(s.dropFirst())
        } else if s.hasPrefix("+") {
            s = String(s.dropFirst())
        }

        // Strip currency symbols ($, €, £) that may appear after sign stripping
        let currencySymbols: Set<Character> = ["$", "€", "£"]
        if let first = s.first, currencySymbols.contains(first) {
            s = String(s.dropFirst())
        }

        // Strip thousand separators (commas when not the decimal separator)
        // We assume the decimal separator is "." and commas are grouping separators.
        s = s.replacingOccurrences(of: ",", with: "")

        // Trim any remaining whitespace after stripping symbols
        s = s.trimmingCharacters(in: .whitespaces)

        guard !s.isEmpty else { return nil }

        // Validate: only digits, at most one dot, optional leading digits
        let validCharSet = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))
        guard s.unicodeScalars.allSatisfy({ validCharSet.contains($0) }) else { return nil }

        // Ensure at most one decimal point
        let dotCount = s.filter { $0 == "." }.count
        guard dotCount <= 1 else { return nil }

        guard let value = Decimal(string: s) else { return nil }

        return isNegative ? -value : value
    }
}

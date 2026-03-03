import Foundation

// MARK: - DateParser

/// Attempts to parse a date string using a set of common formats.
public struct DateParser {

    // MARK: Supported formats

    private static let formats: [String] = [
        "yyyy-MM-dd",
        "MM/dd/yyyy",
        "dd/MM/yyyy",
        "M/d/yyyy",
        "yyyy/MM/dd",
    ]

    // MARK: Formatters (cached)

    // DateFormatter is expensive to construct, so we cache one per format.
    private static let formatters: [DateFormatter] = {
        formats.map { format in
            let df = DateFormatter()
            df.dateFormat = format
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            return df
        }
    }()

    // MARK: Public API

    /// Try to parse `string` using each supported date format, returning the
    /// first successful result, or `nil` if none match.
    public static func parse(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        for formatter in formatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }
}

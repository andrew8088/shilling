import Foundation

enum FormatHelpers {
    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale.current
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    static func currency(_ amount: Decimal) -> String {
        currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    static func date(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    static func monthYear(year: Int, month: Int) -> String {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else {
            return "\(month)/\(year)"
        }
        return monthYearFormatter.string(from: date)
    }
}

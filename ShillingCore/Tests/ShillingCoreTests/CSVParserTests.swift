import Foundation
import Testing
@testable import ShillingCore

// MARK: - CSVParser Tests

@Suite("CSVParser")
struct CSVParserTests {

    // MARK: Basic parsing

    @Test func parseBasicCommaDelimited() throws {
        let csv = """
        Date,Payee,Amount
        2026-01-15,Whole Foods,85.00
        2026-01-16,Netflix,15.99
        """
        let rows = try CSVParser().parse(csv)

        #expect(rows.count == 2)

        #expect(rows[0].values["Date"] == "2026-01-15")
        #expect(rows[0].values["Payee"] == "Whole Foods")
        #expect(rows[0].values["Amount"] == "85.00")

        #expect(rows[1].values["Date"] == "2026-01-16")
        #expect(rows[1].values["Payee"] == "Netflix")
        #expect(rows[1].values["Amount"] == "15.99")
    }

    @Test func parseSingleDataRow() throws {
        let csv = "Name,Value\nAlpha,1"
        let rows = try CSVParser().parse(csv)
        #expect(rows.count == 1)
        #expect(rows[0].values["Name"] == "Alpha")
        #expect(rows[0].values["Value"] == "1")
    }

    // MARK: Delimiters

    @Test func parseSemicolonDelimited() throws {
        let csv = "Date;Payee;Amount\n2026-02-01;Grocery Store;42.50"
        let parser = CSVParser(delimiter: .semicolon)
        let rows = try parser.parse(csv)

        #expect(rows.count == 1)
        #expect(rows[0].values["Date"] == "2026-02-01")
        #expect(rows[0].values["Payee"] == "Grocery Store")
        #expect(rows[0].values["Amount"] == "42.50")
    }

    @Test func parseTabDelimited() throws {
        let csv = "Date\tPayee\tAmount\n2026-03-10\tAmazon\t99.00"
        let parser = CSVParser(delimiter: .tab)
        let rows = try parser.parse(csv)

        #expect(rows.count == 1)
        #expect(rows[0].values["Date"] == "2026-03-10")
        #expect(rows[0].values["Payee"] == "Amazon")
        #expect(rows[0].values["Amount"] == "99.00")
    }

    // MARK: Quoted fields

    @Test func parseQuotedFieldContainingDelimiter() throws {
        // A field with a comma inside quotes must not split on that comma
        let csv = """
        Name,Description
        Widget,"A small, useful widget"
        """
        let rows = try CSVParser().parse(csv)

        #expect(rows.count == 1)
        #expect(rows[0].values["Name"] == "Widget")
        #expect(rows[0].values["Description"] == "A small, useful widget")
    }

    @Test func parseQuotedFieldContainingNewline() throws {
        let csv = "Name,Notes\n\"Alpha\",\"Line one\nLine two\"\nBeta,Plain"
        let rows = try CSVParser().parse(csv)

        #expect(rows.count == 2)
        #expect(rows[0].values["Notes"] == "Line one\nLine two")
        #expect(rows[1].values["Name"] == "Beta")
    }

    @Test func parseEscapedQuotesInsideQuotedField() throws {
        // Doubled quotes ("") represent a literal quote character
        let csv = """
        ID,Description
        1,"He said ""hello"" to me"
        """
        let rows = try CSVParser().parse(csv)

        #expect(rows.count == 1)
        #expect(rows[0].values["Description"] == "He said \"hello\" to me")
    }

    @Test func parseQuotedFieldThatIsEmpty() throws {
        let csv = "A,B,C\n1,\"\",3"
        let rows = try CSVParser().parse(csv)
        #expect(rows.count == 1)
        #expect(rows[0].values["B"] == "")
    }

    // MARK: Whitespace trimming

    @Test func trimsWhitespaceFromHeadersAndValues() throws {
        let csv = " Date , Payee , Amount \n 2026-01-01 , Supermarket , 55.00 "
        let rows = try CSVParser().parse(csv)

        #expect(rows.count == 1)
        #expect(rows[0].values["Date"] == "2026-01-01")
        #expect(rows[0].values["Payee"] == "Supermarket")
        #expect(rows[0].values["Amount"] == "55.00")
    }

    // MARK: Line numbers

    @Test func lineNumbersAreCorrect() throws {
        let csv = "A,B\nfoo,bar\nbaz,qux"
        let rows = try CSVParser().parse(csv)

        // Header is line 1, first data row is line 2, second is line 3
        #expect(rows[0].lineNumber == 2)
        #expect(rows[1].lineNumber == 3)
    }

    // MARK: Trailing newline

    @Test func handlesTrailingNewline() throws {
        let csv = "A,B\n1,2\n"
        let rows = try CSVParser().parse(csv)
        #expect(rows.count == 1)
        #expect(rows[0].values["A"] == "1")
    }

    // MARK: Error cases

    @Test func throwsEmptyInputForEmptyString() {
        #expect(throws: CSVParserError.emptyInput) {
            try CSVParser().parse("")
        }
    }

    @Test func throwsEmptyInputForWhitespaceOnly() {
        #expect(throws: CSVParserError.emptyInput) {
            try CSVParser().parse("   \n  \n  ")
        }
    }

    @Test func throwsNoDataRowsForHeaderOnly() {
        #expect(throws: CSVParserError.noDataRows) {
            try CSVParser().parse("Date,Payee,Amount")
        }
    }

    @Test func throwsNoDataRowsForHeaderWithTrailingNewline() {
        #expect(throws: CSVParserError.noDataRows) {
            try CSVParser().parse("Date,Payee,Amount\n")
        }
    }

    @Test func throwsInconsistentColumnCountWhenRowHasTooFewColumns() {
        let csv = "A,B,C\n1,2"
        #expect(throws: CSVParserError.inconsistentColumnCount(expected: 3, actual: 2, row: 2)) {
            try CSVParser().parse(csv)
        }
    }

    @Test func throwsInconsistentColumnCountWhenRowHasTooManyColumns() {
        let csv = "A,B\n1,2,3"
        #expect(throws: CSVParserError.inconsistentColumnCount(expected: 2, actual: 3, row: 2)) {
            try CSVParser().parse(csv)
        }
    }

    @Test func inconsistentColumnCountReferencesCorrectRow() {
        let csv = "A,B\n1,2\n3,4,5"
        #expect(throws: CSVParserError.inconsistentColumnCount(expected: 2, actual: 3, row: 3)) {
            try CSVParser().parse(csv)
        }
    }
}

// MARK: - DateParser Tests

@Suite("DateParser")
struct DateParserTests {

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    @Test func parsesYYYYMMDD() {
        let result = DateParser.parse("2026-01-15")
        #expect(result == date(year: 2026, month: 1, day: 15))
    }

    @Test func parsesMMSlashDDSlashYYYY() {
        let result = DateParser.parse("01/15/2026")
        #expect(result == date(year: 2026, month: 1, day: 15))
    }

    @Test func parsesDDSlashMMSlashYYYY() {
        // This overlaps with MM/dd/yyyy for unambiguous dates — 15/01/2026 is unambiguous
        let result = DateParser.parse("15/01/2026")
        #expect(result == date(year: 2026, month: 1, day: 15))
    }

    @Test func parsesMSlashDSlashYYYY() {
        let result = DateParser.parse("1/5/2026")
        #expect(result == date(year: 2026, month: 1, day: 5))
    }

    @Test func parsesYYYYSlashMMSlashDD() {
        let result = DateParser.parse("2026/01/15")
        #expect(result == date(year: 2026, month: 1, day: 15))
    }

    @Test func returnsNilForInvalidDate() {
        #expect(DateParser.parse("not-a-date") == nil)
    }

    @Test func returnsNilForEmptyString() {
        #expect(DateParser.parse("") == nil)
    }

    @Test func returnsNilForPartialDate() {
        #expect(DateParser.parse("2026-01") == nil)
    }

    @Test func trimsWhitespace() {
        let result = DateParser.parse("  2026-03-22  ")
        #expect(result == date(year: 2026, month: 3, day: 22))
    }
}

// MARK: - AmountParser Tests

@Suite("AmountParser")
struct AmountParserTests {

    @Test func parsesPositiveDecimal() {
        #expect(AmountParser.parse("100.00") == Decimal(string: "100.00"))
    }

    @Test func parsesNegativeDecimal() {
        #expect(AmountParser.parse("-45.99") == Decimal(string: "-45.99"))
    }

    @Test func parsesPositiveInteger() {
        #expect(AmountParser.parse("42") == Decimal(42))
    }

    @Test func parsesNegativeInteger() {
        #expect(AmountParser.parse("-10") == Decimal(-10))
    }

    @Test func parsesWithLeadingPlusSign() {
        #expect(AmountParser.parse("+25.00") == Decimal(string: "25.00"))
    }

    @Test func parsesWithDollarSymbol() {
        #expect(AmountParser.parse("$99.95") == Decimal(string: "99.95"))
    }

    @Test func parsesWithEuroSymbol() {
        #expect(AmountParser.parse("€49.50") == Decimal(string: "49.50"))
    }

    @Test func parsesWithPoundSymbol() {
        #expect(AmountParser.parse("£200.00") == Decimal(string: "200.00"))
    }

    @Test func parsesNegativeWithCurrencySymbol() {
        #expect(AmountParser.parse("-$12.34") == Decimal(string: "-12.34"))
    }

    @Test func parsesWithThousandSeparator() {
        #expect(AmountParser.parse("1,234.56") == Decimal(string: "1234.56"))
    }

    @Test func parsesWithThousandSeparatorAndCurrencySymbol() {
        #expect(AmountParser.parse("$1,234.56") == Decimal(string: "1234.56"))
    }

    @Test func parsesNegativeWithThousandSeparator() {
        #expect(AmountParser.parse("-1,234.56") == Decimal(string: "-1234.56"))
    }

    @Test func parsesParentheticalNegative() {
        #expect(AmountParser.parse("(45.99)") == Decimal(string: "-45.99"))
    }

    @Test func parsesZero() {
        #expect(AmountParser.parse("0.00") == Decimal(0))
    }

    @Test func parsesZeroWithCurrencySymbol() {
        #expect(AmountParser.parse("$0.00") == Decimal(0))
    }

    @Test func returnsNilForEmptyString() {
        #expect(AmountParser.parse("") == nil)
    }

    @Test func returnsNilForWhitespaceOnly() {
        #expect(AmountParser.parse("   ") == nil)
    }

    @Test func returnsNilForNonNumericString() {
        #expect(AmountParser.parse("not-a-number") == nil)
    }

    @Test func returnsNilForSymbolOnly() {
        #expect(AmountParser.parse("$") == nil)
    }

    @Test func trimsWhitespace() {
        #expect(AmountParser.parse("  42.00  ") == Decimal(string: "42.00"))
    }

    @Test func handlesLargeAmount() {
        #expect(AmountParser.parse("$1,000,000.00") == Decimal(string: "1000000.00"))
    }
}

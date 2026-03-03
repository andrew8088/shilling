import Foundation

// MARK: - CSVParserError

public enum CSVParserError: Error, LocalizedError, Equatable {
    case emptyInput
    case noDataRows
    case inconsistentColumnCount(expected: Int, actual: Int, row: Int)

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "The CSV input is empty."
        case .noDataRows:
            return "The CSV contains a header row but no data rows."
        case let .inconsistentColumnCount(expected, actual, row):
            return "Row \(row) has \(actual) column(s) but expected \(expected)."
        }
    }
}

// MARK: - CSVRow

public struct CSVRow {
    /// Maps header name to field value.
    public let values: [String: String]
    /// 1-based line number in the original input.
    public let lineNumber: Int
}

// MARK: - CSVParser

public struct CSVParser {

    // MARK: Delimiter

    public enum Delimiter: String, CaseIterable {
        case comma = ","
        case semicolon = ";"
        case tab = "\t"
    }

    // MARK: Properties

    public let delimiter: Delimiter

    // MARK: Init

    public init(delimiter: Delimiter = .comma) {
        self.delimiter = delimiter
    }

    // MARK: Public API

    /// Parse CSV content string into structured rows keyed by header name.
    ///
    /// - Parameter content: The full CSV string. The first row is treated as headers.
    /// - Returns: An array of `CSVRow`, one per data row.
    /// - Throws: `CSVParserError` on malformed input.
    public func parse(_ content: String) throws -> [CSVRow] {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CSVParserError.emptyInput
        }

        let rawLines = splitIntoLines(content)
        guard !rawLines.isEmpty else {
            throw CSVParserError.emptyInput
        }

        // Parse each raw line into fields. We track original 1-based line numbers.
        // Lines are already split respecting quoted newlines, so each element
        // is one logical CSV row.
        let delimChar = delimiter.rawValue.first!
        var logicalRows: [(lineNumber: Int, fields: [String])] = []

        var lineNumber = 1
        for rawLine in rawLines {
            let fields = parseFields(from: rawLine, delimiter: delimChar)
            logicalRows.append((lineNumber: lineNumber, fields: fields))
            // Advance lineNumber by the number of real newlines in this logical row
            lineNumber += rawLine.components(separatedBy: "\n").count - 1 + 1
        }

        guard !logicalRows.isEmpty else {
            throw CSVParserError.emptyInput
        }

        // First logical row is the header.
        let headers = logicalRows[0].fields.map { $0.trimmingCharacters(in: .whitespaces) }
        let expectedCount = headers.count

        // Must have at least one data row.
        guard logicalRows.count > 1 else {
            throw CSVParserError.noDataRows
        }

        var result: [CSVRow] = []
        for row in logicalRows.dropFirst() {
            let trimmedFields = row.fields.map { $0.trimmingCharacters(in: .whitespaces) }
            guard trimmedFields.count == expectedCount else {
                throw CSVParserError.inconsistentColumnCount(
                    expected: expectedCount,
                    actual: trimmedFields.count,
                    row: row.lineNumber
                )
            }
            var dict: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                dict[header] = trimmedFields[index]
            }
            result.append(CSVRow(values: dict, lineNumber: row.lineNumber))
        }

        return result
    }

    // MARK: Private helpers

    /// Split content into logical CSV rows (respecting quoted fields that contain newlines).
    private func splitIntoLines(_ content: String) -> [String] {
        var rows: [String] = []
        var current = ""
        var inQuotes = false
        var i = content.startIndex

        while i < content.endIndex {
            let c = content[i]

            if c == "\"" {
                // Check for escaped quote (doubled quote)
                let next = content.index(after: i)
                if inQuotes && next < content.endIndex && content[next] == "\"" {
                    // Escaped quote — include both characters and advance past them
                    current.append(c)
                    current.append(content[next])
                    i = content.index(after: next)
                    continue
                } else {
                    inQuotes.toggle()
                    current.append(c)
                }
            } else if (c == "\n" || c == "\r\n" || c == "\r") && !inQuotes {
                // Handle \r\n as a single newline
                if c == "\r" {
                    let next = content.index(after: i)
                    if next < content.endIndex && content[next] == "\n" {
                        i = next
                    }
                }
                rows.append(current)
                current = ""
            } else if c == "\n" && inQuotes {
                current.append(c)
            } else if c == "\r" && inQuotes {
                let next = content.index(after: i)
                if next < content.endIndex && content[next] == "\n" {
                    current.append("\n")
                    i = content.index(after: next)
                    continue
                } else {
                    current.append("\n")
                }
            } else {
                current.append(c)
            }

            i = content.index(after: i)
        }

        if !current.isEmpty {
            rows.append(current)
        }

        // Drop trailing empty rows (e.g. trailing newline)
        while rows.last == "" {
            rows.removeLast()
        }

        return rows
    }

    /// Parse a single logical CSV row string into its fields, handling quoted fields
    /// (including fields containing the delimiter and escaped doubled-quote sequences).
    private func parseFields(from line: String, delimiter delimChar: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let c = line[i]

            if c == "\"" {
                let next = line.index(after: i)
                if inQuotes && next < line.endIndex && line[next] == "\"" {
                    // Escaped quote: emit a single " and skip both characters
                    current.append("\"")
                    i = line.index(after: next)
                    continue
                } else {
                    inQuotes.toggle()
                }
            } else if c == delimChar && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(c)
            }

            i = line.index(after: i)
        }

        fields.append(current)
        return fields
    }
}

import SwiftUI
import SwiftData
import ShillingCore
import UniformTypeIdentifiers

struct ImportCSVView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Step tracking
    @State private var step: ImportStep = .pickFile

    // File & parse state
    @State private var fileName: String = ""
    @State private var headers: [String] = []
    @State private var rows: [CSVRow] = []
    @State private var parseError: String? = nil

    // Column mapping
    @State private var dateColumn: String = ""
    @State private var payeeColumn: String = ""
    @State private var amountMode: AmountMode = .single
    @State private var amountColumn: String = ""
    @State private var debitColumn: String = ""
    @State private var creditColumn: String = ""
    @State private var memoColumn: String = ""

    // Account selection
    @State private var targetAccount: Account? = nil
    @State private var contraAccount: Account? = nil

    // Result
    @State private var importResult: ImportResult? = nil
    @State private var importError: String? = nil

    enum ImportStep {
        case pickFile, mapColumns, review, result
    }

    enum AmountMode: String, CaseIterable {
        case single = "Single Column"
        case split = "Debit/Credit Columns"
    }

    var body: some View {
        VStack(spacing: 0) {
            stepContent
            Divider()
            bottomBar
        }
        .frame(minWidth: 650, minHeight: 500)
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .pickFile:
            pickFileStep
        case .mapColumns:
            mapColumnsStep
        case .review:
            reviewStep
        case .result:
            resultStep
        }
    }

    // MARK: - Pick File

    private var pickFileStep: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Select a CSV File")
                .font(.title2)
            Text("Choose a bank or credit card statement exported as CSV.")
                .foregroundStyle(.secondary)
            Button("Choose File...") { openFile() }
                .buttonStyle(.borderedProminent)
            if let parseError {
                Text(parseError)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Map Columns

    private var mapColumnsStep: some View {
        Form {
            Section("Column Mapping") {
                columnPicker("Date", selection: $dateColumn)
                columnPicker("Payee", selection: $payeeColumn)

                Picker("Amount Mode", selection: $amountMode) {
                    ForEach(AmountMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                if amountMode == .single {
                    columnPicker("Amount", selection: $amountColumn)
                } else {
                    columnPicker("Debit Column", selection: $debitColumn)
                    columnPicker("Credit Column", selection: $creditColumn)
                }

                columnPicker("Memo (optional)", selection: $memoColumn, optional: true)
            }

            Section("Accounts") {
                AccountPicker(label: "Target Account", selection: $targetAccount)
                AccountPicker(label: "Contra Account", selection: $contraAccount)
                Text("Target = the account this statement is for. Contra = the default other side (e.g. an expense account).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Preview (\(rows.count) rows)") {
                previewTable
            }
        }
        .formStyle(.grouped)
    }

    private func columnPicker(_ label: String, selection: Binding<String>, optional: Bool = false) -> some View {
        Picker(label, selection: selection) {
            if optional {
                Text("None").tag("")
            }
            ForEach(headers, id: \.self) { header in
                Text(header).tag(header)
            }
        }
    }

    private var previewTable: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    ForEach(headers, id: \.self) { header in
                        Text(header)
                            .fontWeight(.semibold)
                            .frame(width: 120, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                    }
                }
                .background(.quaternary)

                Divider()

                // Data rows (first 5)
                ForEach(rows.prefix(5), id: \.lineNumber) { row in
                    HStack(spacing: 0) {
                        ForEach(headers, id: \.self) { header in
                            Text(row.values[header] ?? "")
                                .lineLimit(1)
                                .frame(width: 120, alignment: .leading)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 6)
                        }
                    }
                }

                if rows.count > 5 {
                    Text("... and \(rows.count - 5) more rows")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
            }
        }
    }

    // MARK: - Review

    private var reviewStep: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Ready to Import")
                .font(.title2)

            VStack(alignment: .leading, spacing: 8) {
                summaryRow("File", fileName)
                summaryRow("Rows", "\(rows.count)")
                summaryRow("Date column", dateColumn)
                summaryRow("Payee column", payeeColumn)
                if amountMode == .single {
                    summaryRow("Amount column", amountColumn)
                } else {
                    summaryRow("Debit column", debitColumn)
                    summaryRow("Credit column", creditColumn)
                }
                if !memoColumn.isEmpty {
                    summaryRow("Memo column", memoColumn)
                }
                summaryRow("Target account", targetAccount?.name ?? "—")
                summaryRow("Contra account", contraAccount?.name ?? "—")
            }
            .padding()
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if let importError {
                Text(importError)
                    .foregroundStyle(.red)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .trailing)
            Text(value)
                .fontWeight(.medium)
        }
    }

    // MARK: - Result

    private var resultStep: some View {
        VStack(spacing: 16) {
            Spacer()
            if let result = importResult {
                Image(systemName: result.errors.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(result.errors.isEmpty ? .green : .yellow)
                Text("Import Complete")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 6) {
                    summaryRow("Imported", "\(result.importedCount)")
                    summaryRow("Duplicates skipped", "\(result.skippedDuplicates)")
                    if !result.errors.isEmpty {
                        summaryRow("Errors", "\(result.errors.count)")
                    }
                }
                .padding()
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if !result.errors.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(result.errors.prefix(20), id: \.lineNumber) { err in
                                Text("Row \(err.lineNumber): \(err.message)")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding()
                    }
                    .frame(maxHeight: 150)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if step != .pickFile && step != .result {
                Button("Back") { goBack() }
            }
            Spacer()
            Button(step == .result ? "Done" : "Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            if step == .mapColumns {
                Button("Next") { step = .review }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!mappingValid)
            }
            if step == .review {
                Button("Import") { runImport() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    // MARK: - Validation

    private var mappingValid: Bool {
        guard !dateColumn.isEmpty, !payeeColumn.isEmpty else { return false }
        if amountMode == .single {
            guard !amountColumn.isEmpty else { return false }
        } else {
            guard !debitColumn.isEmpty, !creditColumn.isEmpty else { return false }
        }
        guard targetAccount != nil, contraAccount != nil else { return false }
        return true
    }

    // MARK: - Actions

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText, UTType(filenameExtension: "csv")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let parser = CSVParser()
            let parsed = try parser.parse(content)

            guard let first = parsed.first else {
                parseError = "No data rows found."
                return
            }

            rows = parsed
            headers = Array(first.values.keys).sorted()
            fileName = url.lastPathComponent
            parseError = nil

            // Auto-detect common column names
            autoDetectColumns()
            step = .mapColumns
        } catch {
            parseError = error.localizedDescription
        }
    }

    private func autoDetectColumns() {
        let lowered = Dictionary(uniqueKeysWithValues: headers.map { ($0.lowercased(), $0) })

        for key in ["date", "transaction date", "trans date", "posted date"] {
            if let match = lowered[key] { dateColumn = match; break }
        }
        for key in ["payee", "description", "merchant", "name", "memo"] {
            if let match = lowered[key] { payeeColumn = match; break }
        }
        for key in ["amount", "total", "value"] {
            if let match = lowered[key] { amountColumn = match; break }
        }
        for key in ["debit", "withdrawal", "out"] {
            if let match = lowered[key] { debitColumn = match; break }
        }
        for key in ["credit", "deposit", "in"] {
            if let match = lowered[key] { creditColumn = match; break }
        }
        for key in ["memo", "notes", "reference", "note"] {
            if let match = lowered[key], match != payeeColumn { memoColumn = match; break }
        }

        // If we found debit+credit but not single amount, switch mode
        if amountColumn.isEmpty && !debitColumn.isEmpty && !creditColumn.isEmpty {
            amountMode = .split
        }
    }

    private func goBack() {
        switch step {
        case .mapColumns: step = .pickFile
        case .review: step = .mapColumns
        default: break
        }
    }

    private func runImport() {
        guard let targetAccount, let contraAccount else { return }
        importError = nil

        let mapping: ColumnMapping
        if amountMode == .single {
            mapping = ColumnMapping(
                dateColumn: dateColumn,
                payeeColumn: payeeColumn,
                amountColumn: amountColumn,
                memoColumn: memoColumn.isEmpty ? nil : memoColumn
            )
        } else {
            mapping = ColumnMapping(
                dateColumn: dateColumn,
                payeeColumn: payeeColumn,
                debitColumn: debitColumn,
                creditColumn: creditColumn,
                memoColumn: memoColumn.isEmpty ? nil : memoColumn
            )
        }

        let service = ImportService(context: context)
        do {
            let result = try service.importRows(
                rows,
                mapping: mapping,
                account: targetAccount,
                contraAccount: contraAccount,
                fileName: fileName
            )
            try context.save()
            importResult = result
            step = .result
        } catch {
            importError = error.localizedDescription
        }
    }
}

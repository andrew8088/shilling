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

    enum ImportStep: Int, CaseIterable {
        case pickFile, mapColumns, review, result

        var title: String {
            switch self {
            case .pickFile: return "Select CSV File"
            case .mapColumns: return "Map Columns"
            case .review: return "Review Import"
            case .result: return "Import Complete"
            }
        }

        var subtitle: String {
            switch self {
            case .pickFile: return "Choose the statement file you want to import."
            case .mapColumns: return "Match CSV columns and select accounts."
            case .review: return "Verify mappings before running import."
            case .result: return "Summary of imported rows and issues."
            }
        }

        var shortLabel: String {
            switch self {
            case .pickFile: return "File"
            case .mapColumns: return "Map"
            case .review: return "Review"
            case .result: return "Result"
            }
        }
    }

    enum AmountMode: String, CaseIterable {
        case single = "Single Column"
        case split = "Debit/Credit Columns"
    }

    var body: some View {
        VStack(spacing: 0) {
            stepHeader
            Divider()
            stepContent
            Divider()
            bottomBar
        }
        .frame(minWidth: 650, minHeight: 500)
        .background(Color.shillingBackground)
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(step.title)
                .font(.shillingTitle)
                .foregroundStyle(Color.shillingTextPrimary)

            Text(step.subtitle)
                .font(.shillingBody)
                .foregroundStyle(Color.shillingTextSecondary)

            HStack(spacing: Spacing.xs) {
                ForEach(ImportStep.allCases, id: \.self) { candidate in
                    stepBadge(candidate)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.shillingSurface)
    }

    private func stepBadge(_ candidate: ImportStep) -> some View {
        let isCurrent = candidate == step
        let isComplete = candidate.rawValue < step.rawValue
        let badgeColor: Color = isCurrent || isComplete ? .shillingAccent : .shillingTextTertiary

        return HStack(spacing: Spacing.xxs) {
            ZStack {
                Circle()
                    .fill(isCurrent || isComplete ? Color.shillingAccent : Color.clear)
                    .overlay(
                        Circle()
                            .stroke(Color.shillingBorder, lineWidth: isCurrent || isComplete ? 0 : 1)
                    )
                    .frame(width: 16, height: 16)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white)
                } else {
                    Text("\(candidate.rawValue + 1)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isCurrent ? Color.white : Color.shillingTextSecondary)
                }
            }

            Text(candidate.shortLabel)
                .font(.shillingCaption)
                .foregroundStyle(badgeColor)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 6)
        .background(isCurrent ? Color.shillingAccent.opacity(0.14) : Color.clear)
        .clipShape(Capsule())
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
        ScrollView {
            VStack(spacing: Spacing.xl) {
                CardView {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(Color.shillingTextTertiary)

                        Text("Select a CSV File")
                            .font(.shillingTitle)
                            .foregroundStyle(Color.shillingTextPrimary)

                        Text("Choose a bank or credit card statement exported as CSV.")
                            .font(.shillingBody)
                            .foregroundStyle(Color.shillingTextSecondary)
                            .multilineTextAlignment(.center)

                        Button("Choose File...") { openFile() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)

                        if let parseError {
                            Text(parseError)
                                .font(.shillingCaption)
                                .foregroundStyle(Color.shillingNegative)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: 480)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.xl)
        }
        .background(Color.shillingBackground)
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
                .pickerStyle(.segmented)

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
                    .font(.shillingCaption)
                    .foregroundStyle(Color.shillingTextSecondary)
            }

            Section("Preview (\(rows.count) rows)") {
                previewTable
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.shillingBackground)
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
        CardView {
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(headers, id: \.self) { header in
                            Text(header)
                                .font(.shillingCaption)
                                .foregroundStyle(Color.shillingTextSecondary)
                                .frame(width: 120, alignment: .leading)
                                .padding(.vertical, Spacing.xs)
                                .padding(.horizontal, Spacing.xs)
                        }
                    }
                    .background(Color.shillingSurfaceSecondary)

                    Divider()

                    ForEach(rows.prefix(5), id: \.lineNumber) { row in
                        HStack(spacing: 0) {
                            ForEach(headers, id: \.self) { header in
                                Text(row.values[header] ?? "")
                                    .font(.shillingBody)
                                    .foregroundStyle(Color.shillingTextPrimary)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                                    .padding(.vertical, Spacing.xxs)
                                    .padding(.horizontal, Spacing.xs)
                            }
                        }
                    }

                    if rows.count > 5 {
                        Text("... and \(rows.count - 5) more rows")
                            .font(.shillingCaption)
                            .foregroundStyle(Color.shillingTextSecondary)
                            .padding(Spacing.xs)
                    }
                }
            }
        }
    }

    // MARK: - Review

    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Color.shillingAccent)

                Text("Ready to Import")
                    .font(.shillingTitle)
                    .foregroundStyle(Color.shillingTextPrimary)

                CardView {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
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
                }
                .frame(maxWidth: 520)

                if let importError {
                    Text(importError)
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingNegative)
                        .frame(maxWidth: 520, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.xl)
        }
        .background(Color.shillingBackground)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.shillingCaption)
                .foregroundStyle(Color.shillingTextSecondary)
                .frame(width: 120, alignment: .trailing)
            Text(value)
                .font(.shillingBody)
                .foregroundStyle(Color.shillingTextPrimary)
                .lineLimit(1)
        }
    }

    // MARK: - Result

    private var resultStep: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                if let result = importResult {
                    Image(systemName: result.errors.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(result.errors.isEmpty ? Color.shillingPositive : Color.shillingWarning)

                    Text("Import Complete")
                        .font(.shillingTitle)
                        .foregroundStyle(Color.shillingTextPrimary)

                    CardView {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            resultCountRow("Imported", value: result.importedCount, color: .shillingPositive)
                            resultCountRow("Duplicates skipped", value: result.skippedDuplicates, color: .shillingTextSecondary)
                            if !result.errors.isEmpty {
                                resultCountRow("Errors", value: result.errors.count, color: .shillingNegative)
                            }
                        }
                    }
                    .frame(maxWidth: 520)

                    if !result.errors.isEmpty {
                        CardView {
                            ScrollView {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    ForEach(result.errors.prefix(20), id: \.lineNumber) { err in
                                        Text("Row \(err.lineNumber): \(err.message)")
                                            .font(.shillingCaption)
                                            .foregroundStyle(Color.shillingNegative)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 180)
                        }
                        .frame(maxWidth: 520)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.xl)
        }
        .background(Color.shillingBackground)
    }

    private func resultCountRow(_ label: String, value: Int, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.shillingCaption)
                .foregroundStyle(Color.shillingTextSecondary)
            Spacer()
            Text("\(value)")
                .font(.shillingAmountMono)
                .foregroundStyle(color)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: Spacing.sm) {
            if step != .pickFile && step != .result {
                Button("Back") { goBack() }
                    .buttonStyle(.bordered)
            }
            Spacer()
            if step == .result {
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            if step == .mapColumns {
                Button("Next") { step = .review }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!mappingValid)
            }
            if step == .review {
                Button("Import") { runImport() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(Spacing.md)
        .background(Color.shillingSurface)
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

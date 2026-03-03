import SwiftUI
import SwiftData
import ShillingCore

struct TransactionListView: View {
    @Query(sort: \Txn.date, order: .reverse) private var allTransactions: [Txn]

    @State private var searchText = ""
    @State private var filterAccount: Account? = nil
    @State private var startDate: Date? = nil
    @State private var endDate: Date? = nil
    @State private var minAmount: Decimal = .zero
    @State private var maxAmount: Decimal = .zero
    @State private var showAdvancedFilters = false
    @State private var showingNewTransactionSheet = false
    @State private var selectedTransaction: Txn? = nil

    private var activeAmountRange: (min: Decimal?, max: Decimal?) {
        let min = minAmount > .zero ? minAmount : nil
        let max = maxAmount > .zero ? maxAmount : nil

        if let min, let max, min > max {
            return (min: max, max: min)
        }
        return (min: min, max: max)
    }

    private var hasAdvancedFilters: Bool {
        startDate != nil || endDate != nil || activeAmountRange.min != nil || activeAmountRange.max != nil
    }

    private var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || filterAccount != nil || hasAdvancedFilters
    }

    private var filtered: [Txn] {
        let calendar = Calendar.current
        let searchQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let amountRange = activeAmountRange

        return allTransactions.filter { tx in
            if let filterAccount {
                let id = filterAccount.id
                guard tx.entries.contains(where: { $0.account?.id == id }) else { return false }
            }
            if !searchQuery.isEmpty {
                guard tx.payee.lowercased().contains(searchQuery) else { return false }
            }
            if let startDate {
                let startOfDay = calendar.startOfDay(for: startDate)
                if tx.date < startOfDay { return false }
            }
            if let endDate {
                let startOfDay = calendar.startOfDay(for: endDate)
                guard let dayAfterEnd = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                    return false
                }
                if tx.date >= dayAfterEnd { return false }
            }
            let amount = transactionAmount(for: tx)
            if let min = amountRange.min, amount < min { return false }
            if let max = amountRange.max, amount > max { return false }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            if filtered.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.rectangle",
                    title: "No Transactions",
                    message: hasActiveFilters
                        ? "No transactions match the current filters."
                        : "Create a transaction to get started."
                )
            } else {
                List(filtered, id: \.id, selection: $selectedTransaction) { transaction in
                    TransactionRow(transaction: transaction)
                        .tag(transaction)
                }
            }
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewTransactionSheet = true
                } label: {
                    Label("New Transaction", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewTransactionSheet) {
            TransactionFormSheet(transaction: nil)
        }
        .sheet(item: $selectedTransaction) { tx in
            TransactionFormSheet(transaction: tx)
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search payee...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                AccountPicker(label: "Account", selection: $filterAccount)
                    .frame(maxWidth: 200)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAdvancedFilters.toggle()
                    }
                } label: {
                    Label("Advanced", systemImage: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(.borderless)

                if hasActiveFilters {
                    Button("Clear") {
                        clearFilters()
                    }
                    .buttonStyle(.borderless)
                }
            }

            if showAdvancedFilters || hasAdvancedFilters {
                advancedFilters
            }
        }
        .padding()
    }

    private var advancedFilters: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Toggle("From", isOn: startDateEnabled)
                        .toggleStyle(.checkbox)
                        .font(.shillingCaption)
                    if startDate != nil {
                        DatePicker("From", selection: startDateBinding, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Toggle("To", isOn: endDateEnabled)
                        .toggleStyle(.checkbox)
                        .font(.shillingCaption)
                    if endDate != nil {
                        DatePicker("To", selection: endDateBinding, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Min")
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingTextSecondary)
                    CurrencyField(label: "0.00", amount: $minAmount)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Max")
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingTextSecondary)
                    CurrencyField(label: "0.00", amount: $maxAmount)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var startDateEnabled: Binding<Bool> {
        Binding(
            get: { startDate != nil },
            set: { enabled in
                startDate = enabled ? (startDate ?? Date()) : nil
            }
        )
    }

    private var endDateEnabled: Binding<Bool> {
        Binding(
            get: { endDate != nil },
            set: { enabled in
                endDate = enabled ? (endDate ?? Date()) : nil
            }
        )
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { startDate ?? Date() },
            set: { startDate = $0 }
        )
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { endDate ?? Date() },
            set: { endDate = $0 }
        )
    }

    private func clearFilters() {
        searchText = ""
        filterAccount = nil
        startDate = nil
        endDate = nil
        minAmount = .zero
        maxAmount = .zero
        showAdvancedFilters = false
    }

    private func transactionAmount(for transaction: Txn) -> Decimal {
        let debitTotal = transaction.entries
            .filter { $0.type == .debit }
            .reduce(Decimal.zero) { total, entry in
                total + absolute(entry.amount)
            }

        if debitTotal > .zero {
            return debitTotal
        }

        return transaction.entries
            .filter { $0.type == .credit }
            .reduce(Decimal.zero) { total, entry in
                total + absolute(entry.amount)
            }
    }

    private func absolute(_ value: Decimal) -> Decimal {
        value < .zero ? -value : value
    }
}

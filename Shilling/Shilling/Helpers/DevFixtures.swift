#if DEBUG
import Foundation
import SwiftData
import ShillingCore

enum DevFixtures {
    static func seed(context: ModelContext) throws {
        let accounts = try context.fetch(FetchDescriptor<Account>())

        func find(_ name: String) -> Account? {
            accounts.first { $0.name == name }
        }

        guard let chequing = find("Chequing"),
              let savings = find("Savings"),
              let creditCard = find("Credit Card"),
              let mortgage = find("Mortgage"),
              let groceries = find("Groceries"),
              let dining = find("Dining"),
              let transport = find("Transport"),
              let utilities = find("Utilities"),
              let housing = find("Housing"),
              let entertainment = find("Entertainment"),
              let salary = find("Salary"),
              let otherIncome = find("Other Income"),
              let interest = find("Interest"),
              let openingBalances = find("Opening Balances")
        else {
            return
        }

        let txService = TransactionService(context: context)
        let budgetService = BudgetService(context: context)

        let cal = Calendar.current
        let now = Date()
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)

        func date(_ m: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: year, month: m, day: d))!
        }

        // Opening balances (as of start of year)
        let jan1 = date(1, 1)
        try txService.createOpeningBalance(account: chequing, amount: 4250, date: jan1, openingBalancesAccount: openingBalances)
        try txService.createOpeningBalance(account: savings, amount: 15000, date: jan1, openingBalancesAccount: openingBalances)
        try txService.createOpeningBalance(account: creditCard, amount: 820, date: jan1, openingBalancesAccount: openingBalances)
        try txService.createOpeningBalance(account: mortgage, amount: 285000, date: jan1, openingBalancesAccount: openingBalances)

        // --- January transactions ---
        try txService.createTransaction(date: date(1, 3), payee: "Metro Grocery", entries: [
            EntryData(account: groceries, amount: 87.43, type: .debit),
            EntryData(account: chequing, amount: 87.43, type: .credit),
        ])
        try txService.createTransaction(date: date(1, 5), payee: "Shell Gas Station", entries: [
            EntryData(account: transport, amount: 62.10, type: .debit),
            EntryData(account: chequing, amount: 62.10, type: .credit),
        ])
        try txService.createTransaction(date: date(1, 8), payee: "Netflix", entries: [
            EntryData(account: entertainment, amount: 16.99, type: .debit),
            EntryData(account: creditCard, amount: 16.99, type: .credit),
        ])
        try txService.createTransaction(date: date(1, 10), payee: "Sushi Palace", entries: [
            EntryData(account: dining, amount: 54.80, type: .debit),
            EntryData(account: creditCard, amount: 54.80, type: .credit),
        ])
        try txService.createTransaction(date: date(1, 15), payee: "Employer Inc.", entries: [
            EntryData(account: chequing, amount: 3200, type: .debit),
            EntryData(account: salary, amount: 3200, type: .credit),
        ])
        try txService.createTransaction(date: date(1, 15), payee: "Hydro One", entries: [
            EntryData(account: utilities, amount: 145.20, type: .debit),
            EntryData(account: chequing, amount: 145.20, type: .credit),
        ])
        // Mortgage payment (split: principal + interest)
        try txService.createTransaction(date: date(1, 18), payee: "TD Mortgage Payment", entries: [
            EntryData(account: mortgage, amount: 980, type: .debit),
            EntryData(account: interest, amount: 620, type: .debit),
            EntryData(account: chequing, amount: 1600, type: .credit),
        ])
        try txService.createTransaction(date: date(1, 20), payee: "Costco", entries: [
            EntryData(account: groceries, amount: 215.67, type: .debit),
            EntryData(account: chequing, amount: 215.67, type: .credit),
        ])
        try txService.createTransaction(date: date(1, 25), payee: "Transfer to Savings", entries: [
            EntryData(account: savings, amount: 500, type: .debit),
            EntryData(account: chequing, amount: 500, type: .credit),
        ])
        try txService.createTransaction(date: date(1, 28), payee: "Credit Card Payment", entries: [
            EntryData(account: creditCard, amount: 891.79, type: .debit),
            EntryData(account: chequing, amount: 891.79, type: .credit),
        ])
        try txService.createTransaction(date: date(1, 30), payee: "Employer Inc.", entries: [
            EntryData(account: chequing, amount: 3200, type: .debit),
            EntryData(account: salary, amount: 3200, type: .credit),
        ])

        // --- February transactions ---
        try txService.createTransaction(date: date(2, 2), payee: "Loblaws", entries: [
            EntryData(account: groceries, amount: 134.52, type: .debit),
            EntryData(account: chequing, amount: 134.52, type: .credit),
        ])
        try txService.createTransaction(date: date(2, 4), payee: "Uber", entries: [
            EntryData(account: transport, amount: 28.50, type: .debit),
            EntryData(account: creditCard, amount: 28.50, type: .credit),
        ])
        try txService.createTransaction(date: date(2, 7), payee: "The Keg", entries: [
            EntryData(account: dining, amount: 112.40, type: .debit),
            EntryData(account: creditCard, amount: 112.40, type: .credit),
        ])
        try txService.createTransaction(date: date(2, 10), payee: "Spotify", entries: [
            EntryData(account: entertainment, amount: 11.99, type: .debit),
            EntryData(account: creditCard, amount: 11.99, type: .credit),
        ])
        try txService.createTransaction(date: date(2, 12), payee: "Enbridge Gas", entries: [
            EntryData(account: utilities, amount: 198.30, type: .debit),
            EntryData(account: chequing, amount: 198.30, type: .credit),
        ])
        try txService.createTransaction(date: date(2, 14), payee: "Freelance Project", entries: [
            EntryData(account: chequing, amount: 750, type: .debit),
            EntryData(account: otherIncome, amount: 750, type: .credit),
        ])
        try txService.createTransaction(date: date(2, 15), payee: "Employer Inc.", entries: [
            EntryData(account: chequing, amount: 3200, type: .debit),
            EntryData(account: salary, amount: 3200, type: .credit),
        ])
        try txService.createTransaction(date: date(2, 15), payee: "Rent", entries: [
            EntryData(account: housing, amount: 1800, type: .debit),
            EntryData(account: chequing, amount: 1800, type: .credit),
        ])
        try txService.createTransaction(date: date(2, 18), payee: "TD Mortgage Payment", entries: [
            EntryData(account: mortgage, amount: 985, type: .debit),
            EntryData(account: interest, amount: 615, type: .debit),
            EntryData(account: chequing, amount: 1600, type: .credit),
        ])
        try txService.createTransaction(date: date(2, 22), payee: "Farm Boy", entries: [
            EntryData(account: groceries, amount: 97.81, type: .debit),
            EntryData(account: chequing, amount: 97.81, type: .credit),
        ])
        try txService.createTransaction(date: date(2, 25), payee: "Transfer to Savings", entries: [
            EntryData(account: savings, amount: 500, type: .debit),
            EntryData(account: chequing, amount: 500, type: .credit),
        ])
        try txService.createTransaction(date: date(2, 27), payee: "Credit Card Payment", entries: [
            EntryData(account: creditCard, amount: 152.89, type: .debit),
            EntryData(account: chequing, amount: 152.89, type: .credit),
        ])
        try txService.createTransaction(date: date(2, 28), payee: "Employer Inc.", entries: [
            EntryData(account: chequing, amount: 3200, type: .debit),
            EntryData(account: salary, amount: 3200, type: .credit),
        ])

        // --- March transactions (current month, partial) ---
        try txService.createTransaction(date: date(3, 1), payee: "Metro Grocery", entries: [
            EntryData(account: groceries, amount: 76.23, type: .debit),
            EntryData(account: chequing, amount: 76.23, type: .credit),
        ])
        try txService.createTransaction(date: date(3, 2), payee: "Tim Hortons", entries: [
            EntryData(account: dining, amount: 8.45, type: .debit),
            EntryData(account: chequing, amount: 8.45, type: .credit),
        ])

        // --- Budget targets ---
        // Set for all 3 months
        let budgetTargets: [(Account, Decimal)] = [
            (groceries, 500),
            (dining, 200),
            (transport, 150),
            (utilities, 250),
            (housing, 1800),
            (entertainment, 50),
            (interest, 700),
        ]

        for m in 1...3 {
            for (account, amount) in budgetTargets {
                try budgetService.setBudget(account: account, year: year, month: m, amount: amount)
            }
        }

        try context.save()
    }
}
#endif

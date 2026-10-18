//
//  DevSeedAccountLines.swift
//  Yala
//
//  Seed AISLADO para `-uitest-seed tarjeta-dos-lineas` (tarjeta con varias divisas, entrega 2): una tarjeta de
//  crédito en soles con su línea en dólares, una cuenta suelta en soles y otra en dólares con movimientos, que es la
//  que se vincula en los tests. Sin el generador aleatorio, para que las cifras del Panel sean las de aquí.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedAccountLines {

    /// Los literales que buscan los XCUITest. Viven aquí para que seed y test no diverjan.
    enum UITest {
        static let profile = "tarjeta-dos-lineas"
        /// La tarjeta: principal en soles.
        static let cardName = "Visa QA"
        /// Su línea en dólares.
        static let lineName = "Visa QA · USD"
        /// Suelta, en soles: no se puede vincular a la tarjeta (misma divisa).
        static let savingsName = "Ahorros QA"
        /// Suelta, en dólares y con movimientos: la que se vincula.
        static let dollarsName = "Dólares QA"
        static let cardSpent: Double = -1_250
        static let lineSpent: Double = -80
        static let dollarsIncome: Double = 300
        static let dollarsExpense: Double = -45
    }

    @MainActor
    static func create(subcategoryLookup: [String: Subcategory], in context: ModelContext) {
        let card = Account(
            name: UITest.cardName, currencyCode: "PEN", colorHex: "#3D36B3",
            iconName: "creditcard.fill", type: AccountType.creditCard.rawValue)
        card.creditCardPaymentReminder = true
        card.creditCardPaymentDay = 15
        let line = Account(
            name: UITest.lineName, currencyCode: "USD", colorHex: "#3D36B3",
            iconName: "creditcard.fill", type: AccountType.creditCard.rawValue)
        line.parentAccountID = card.shortcutID
        let savings = Account(
            name: UITest.savingsName, currencyCode: "PEN", colorHex: "#4CB963",
            iconName: "banknote.fill", type: AccountType.savings.rawValue)
        let dollars = Account(
            name: UITest.dollarsName, currencyCode: "USD", colorHex: "#FF7F11",
            iconName: "dollarsign.circle.fill", type: AccountType.savings.rawValue)
        [card, line, savings, dollars].forEach { context.insert($0) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        }
        let expenseSub = subcategoryLookup.values.first { !$0.safeCategory.isIncome }
        let incomeSub = subcategoryLookup.values.first { $0.safeCategory.isIncome }

        func insert(_ note: String, _ amount: Double, _ date: Date, _ account: Account, _ sub: Subcategory?) {
            let tx = TransactionItem(
                date: date, amount: amount, currencyCode: account.currencyCode, note: note,
                category: sub?.safeCategory, subcategory: sub, account: account)
            tx.createdAt = date
            context.insert(tx)
            tx.recalculatePreferredCurrency(context: context)
        }
        insert("Supermercado QA", UITest.cardSpent, day(2), card, expenseSub)
        insert("Hotel QA", UITest.lineSpent, day(3), line, expenseSub)
        insert("Sueldo QA", 2_000, day(4), savings, incomeSub)
        insert("Freelance QA", UITest.dollarsIncome, day(4), dollars, incomeSub)
        insert("Suscripción QA", UITest.dollarsExpense, day(1), dollars, expenseSub)
    }
}
#endif

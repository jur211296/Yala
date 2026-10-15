//
//  DevSeedAccountRemoval.swift
//  Yala
//
//  Seed AISLADO para `-uitest-seed cuenta-con-movimientos`: el caso del QA guiado del 15-oct
//  (eliminar «Efectivo QA» con dos gastos dentro). Ticket
//  `tablero-al-eliminar-una-cuenta-sus-movimientos-q-ofst`.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedAccountRemoval {

    /// Los literales que el XCUITest busca. Viven aquí para que seed y test no diverjan.
    enum UITest {
        static let profile = "cuenta-con-movimientos"
        /// La cuenta que se elimina: dos gastos, en soles.
        static let sourceName = "Efectivo QA"
        /// Destino en la misma divisa.
        static let samePENName = "Banco QA"
        /// Destino en otra divisa (dólares, sin movimientos).
        static let usdName = "Dólares QA"
        static let taxiNote = "Taxi"
        static let phoneNote = "Teléfono"
        static let taxiAmount: Double = -25
        static let phoneAmount: Double = -33
        static let salaryNote = "Sueldo QA"
    }

    @MainActor
    static func create(subcategoryLookup: [String: Subcategory], in context: ModelContext) {
        let source = Account(
            name: UITest.sourceName, currencyCode: "PEN", colorHex: "#FF7F11",
            iconName: "banknote.fill", type: AccountType.cash.rawValue)
        let bank = Account(
            name: UITest.samePENName, currencyCode: "PEN", colorHex: "#6366F1",
            iconName: "creditcard.fill", type: AccountType.checking.rawValue)
        let usd = Account(
            name: UITest.usdName, currencyCode: "USD", colorHex: "#4CB963",
            iconName: "dollarsign.circle.fill", type: AccountType.savings.rawValue)
        context.insert(source)
        context.insert(bank)
        context.insert(usd)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        }
        let expenseSub = subcategoryLookup[L10n.Subcategory.phone]
            ?? subcategoryLookup.values.first { !$0.safeCategory.isIncome }
        let incomeSub = subcategoryLookup.values.first { $0.safeCategory.isIncome }

        func insert(_ note: String, _ amount: Double, _ date: Date, _ account: Account, _ sub: Subcategory?) {
            let tx = TransactionItem(
                date: date, amount: amount, currencyCode: account.currencyCode, note: note,
                category: sub?.safeCategory, subcategory: sub, account: account)
            tx.createdAt = date
            context.insert(tx)
            tx.recalculatePreferredCurrency(context: context)
        }
        insert(UITest.taxiNote, UITest.taxiAmount, day(1), source, expenseSub)
        insert(UITest.phoneNote, UITest.phoneAmount, day(2), source, expenseSub)
        insert(UITest.salaryNote, 1000, day(3), bank, incomeSub)
    }
}
#endif

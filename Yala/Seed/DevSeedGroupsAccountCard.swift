//
//  DevSeedGroupsAccountCard.swift
//  Yala
//
//  Seed AISLADO para `-uitest-seed cuentas-de-grupos` (card extra de Jürgen del 2026-11-03: las cuentas de Grupos en una
//  sola tarjeta). Una cuenta propia en soles y tres grupos con lo que aportan a las cuentas de sistema: dos en soles
//  («Grupos PEN», uno a favor y otro en contra) y uno en dólares («Grupos USD»). Sin el generador aleatorio, para que las
//  cifras del Panel sean las de aquí.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedGroupsAccountCard {

    /// Los literales que buscan los tests. Viven aquí para que seed y test no diverjan.
    enum UITest {
        static let profile = "cuentas-de-grupos"
        static let ownAccountName = "Sueldo QA"
        static let tripName = "Viaje a Cusco"
        static let flatName = "Depa Miraflores"
        static let japanName = "Japón"
        static let tripLent: Double = 120
        static let flatOwed: Double = -45
        static let japanLent: Double = 80
    }

    @MainActor
    static func create(subcategoryLookup: [String: Subcategory], in context: ModelContext) {
        let own = Account(
            name: UITest.ownAccountName, currencyCode: "PEN", colorHex: "#4CB963",
            iconName: "banknote.fill", type: AccountType.savings.rawValue)
        context.insert(own)
        let incomeSub = subcategoryLookup.values.first { $0.safeCategory.isIncome && !$0.isAnySystem }
        let salary = TransactionItem(
            date: DevSeedAccountLines.seedDate(daysAgo: 5), amount: 3_000, currencyCode: "PEN", note: "Sueldo",
            category: incomeSub?.safeCategory, subcategory: incomeSub, account: own)
        context.insert(salary)
        salary.recalculatePreferredCurrency(context: context)

        do {
            try leg(group: UITest.tripName, zone: "zona-viaje-cusco", currency: "PEN", amount: UITest.tripLent,
                    daysAgo: 1, in: context)
            try leg(group: UITest.flatName, zone: "zona-depa", currency: "PEN", amount: UITest.flatOwed,
                    daysAgo: 2, in: context)
            try leg(group: UITest.japanName, zone: "zona-japon", currency: "USD", amount: UITest.japanLent,
                    daysAgo: 3, in: context)
        } catch {
            print("DevSeedGroupsAccountCard: Error: \(error)")
        }
    }

    /// Un grupo con un gasto y su pata en la cuenta de sistema de su moneda: positiva si prestaste, negativa si debes.
    @MainActor
    private static func leg(
        group name: String, zone: String, currency: String, amount: Double, daysAgo: Int, in context: ModelContext
    ) throws {
        let group = SplitGroup(name: name, currencyCode: currency)
        group.cloudKitZoneID = zone
        group.isBackendGroup = true
        context.insert(group)
        let me = SplitMember(groupZoneID: zone, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        context.insert(SplitMember(groupZoneID: zone, displayName: "Ana"))
        let date = DevSeedAccountLines.seedDate(daysAgo: daysAgo)
        let expense = SplitExpense(
            groupZoneID: zone, amount: abs(amount) * 2, currencyCode: currency, expenseDescription: "Gasto de \(name)",
            date: date, paidByMemberID: me.id.uuidString)
        context.insert(expense)

        let account = try GroupBridgeSystemEntities.ensureSystemAccount(
            currencyCode: currency, colorHint: group.colorHex, context: context)
        let role: GroupBridgeSystemEntities.SystemSubcategoryRole = amount >= 0 ? .openingBalanceOwed : .openingBalanceDebt
        let sub = try GroupBridgeSystemEntities.systemSubcategory(role: role, context: context)
        let tx = TransactionItem(
            date: date, amount: amount, currencyCode: currency, note: "Gasto de \(name)",
            category: sub.safeCategory, subcategory: sub, account: account)
        tx.splitExpenseID = expense.id.uuidString
        tx.splitGroupZoneID = zone
        tx.splitTotalAmount = abs(amount) * 2
        tx.createdAt = date
        context.insert(tx)
        tx.recalculatePreferredCurrency(context: context)
    }
}
#endif

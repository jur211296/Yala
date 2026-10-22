//
//  DevSeedGroupRowsWithoutGroup.swift
//  Yala
//
//  Seeds AISLADOS de las filas de grupo sin su grupo o sin su cuenta:
//  - `-uitest-seed gasto-de-grupo-sin-su-grupo`: un gasto de grupo en la Bandeja cuyo grupo no está en este teléfono
//    (ticket `prior-icloud-group-records-summed-without-their-group`).
//  - `-uitest-seed pata-de-grupo-sin-cuenta`: el corpus de `movimientos-sin-cuenta` más una cena de grupo que pagué desde
//    «Efectivo QA» antes de eliminarla (ticket `orphaned-group-records-stay-out-of-the-notice`).
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedGroupRowsWithoutGroup {

    /// Los literales que el XCUITest busca. Viven aquí para que seed y test no diverjan.
    enum UITest {
        static let draftProfile = "gasto-de-grupo-sin-su-grupo"
        static let legProfile = "pata-de-grupo-sin-cuenta"
        /// El gasto de grupo que llegó de iCloud sin su grupo.
        static let foreignDraftNote = "Cena del viaje (grupo de otro teléfono)"
        /// Un borrador normal, para ver que el resto de la Bandeja no cambia.
        static let personalDraftNote = "Café"
        /// La pata real de la cena de grupo que pagué desde «Efectivo QA».
        static let groupLegNote = "Cena del grupo"
        static let groupLegAmount: Double = -60
    }

    /// Un gasto de grupo pendiente de un grupo que aquí no existe (ni su zona ni su gasto), como lo deja «Sumarlos a mis
    /// datos» al volver a iCloud, y un borrador personal al lado.
    @MainActor
    static func createForeignGroupDraft(in context: ModelContext) {
        let foreign = InboxDraft(
            note: UITest.foreignDraftNote, amount: -45, date: .now, account: nil, subcategory: nil,
            sourceType: .groupExpense, confidenceAmount: 1, confidenceDate: 1, confidenceMerchant: 1,
            confidenceSubcategory: nil, needsUserInput: [DraftInputRequirement.account],
            splitExpenseID: UUID().uuidString, splitGroupZoneID: "zona-de-otro-telefono",
            splitSettlementID: nil, targetTransactionID: nil)
        context.insert(foreign)
        let personal = InboxDraft(
            note: UITest.personalDraftNote, amount: -8, date: .now, account: nil, subcategory: nil,
            sourceType: .voice, confidenceAmount: 1, confidenceDate: 1, confidenceMerchant: 1,
            confidenceSubcategory: nil, needsUserInput: ["account", "subcategory"],
            splitExpenseID: nil, splitGroupZoneID: nil, splitSettlementID: nil, targetTransactionID: nil)
        context.insert(personal)
    }

    /// El corpus de `movimientos-sin-cuenta` y, antes de eliminar «Efectivo QA», una cena de grupo de 60 que pagué desde
    /// ella: su pata real (-60, puntero al gasto) se queda sin cuenta; el préstamo (+40) sigue en «Grupos».
    @MainActor
    static func createGroupLegWithoutAccount(subcategoryLookup: [String: Subcategory], in context: ModelContext) {
        DevSeedAccountRemoval.create(subcategoryLookup: subcategoryLookup, in: context)
        let sourceName = DevSeedAccountRemoval.UITest.sourceName
        do {
            guard let source = try context.fetch(FetchDescriptor<Account>(
                predicate: #Predicate { $0.name == sourceName })).first else { return }

            let zone = "zona-cena-qa"
            let group = SplitGroup(name: "Cena QA", currencyCode: "PEN")
            group.cloudKitZoneID = zone
            group.isBackendGroup = true
            context.insert(group)
            let me = SplitMember(groupZoneID: zone, displayName: "Yo", isCurrentUser: true)
            let other = SplitMember(groupZoneID: zone, displayName: "Ana")
            context.insert(me)
            context.insert(other)
            let date = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
            let expense = SplitExpense(
                groupZoneID: zone, amount: -UITest.groupLegAmount, currencyCode: "PEN",
                expenseDescription: UITest.groupLegNote, date: date, paidByMemberID: me.id.uuidString)
            context.insert(expense)

            let groupsAccount = try GroupBridgeSystemEntities.ensureSystemAccount(
                currencyCode: "PEN", colorHint: group.colorHex, context: context)
            let loan = try GroupBridgeSystemEntities.systemSubcategory(role: .loanToGroups, context: context)
            let sub = subcategoryLookup.values.first { !$0.safeCategory.isIncome && !$0.isAnySystem }

            let real = TransactionItem(
                date: date, amount: UITest.groupLegAmount, currencyCode: "PEN", note: UITest.groupLegNote,
                category: sub?.safeCategory, subcategory: sub, account: source)
            real.splitExpenseID = expense.id.uuidString
            real.splitGroupZoneID = zone
            real.splitTotalAmount = -UITest.groupLegAmount
            context.insert(real)
            real.recalculatePreferredCurrency(context: context)

            let lent = TransactionItem(
                date: date, amount: 40, currencyCode: "PEN", note: UITest.groupLegNote,
                category: loan.safeCategory, subcategory: loan, account: groupsAccount)
            lent.splitExpenseID = expense.id.uuidString
            lent.splitGroupZoneID = zone
            lent.splitTotalAmount = -UITest.groupLegAmount
            context.insert(lent)
            lent.recalculatePreferredCurrency(context: context)

            // Eliminar «Efectivo QA» como antes de la 2.1: `.nullify` deja Taxi, Teléfono y la pata real sin cuenta.
            context.delete(source)
        } catch {
            print("DevSeedGroupRowsWithoutGroup: Error: \(error)")
        }
    }
}
#endif

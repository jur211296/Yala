//
//  DevSeedGroupBridgeLeftovers.swift
//  Yala
//
//  `-uitest-seed grupos-repetidos`: el estado del teléfono de Jürgen el 2026-11-09, con datos ficticios. Dos gastos de
//  grupo que pagué con cuenta («Google One» en USD y «Gasolina» en PEN, a partes iguales con Pia), puenteados en local
//  con su cuenta, y después una pasada REMOTA del puente que no vio sus patas (las dos sin cuenta en ese instante, como
//  las deja el canal personal al re-aplicar su eco). Quedan: el borrador «Elige cuenta» en la Bandeja y el «Préstamo a
//  grupos» repetido en Registros.
//
//  Lo sobrante se fecha dos días atrás: es «lo de antes» del arreglo, lo que la limpieza automática no toca y el aviso
//  de la Bandeja sí enseña.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedGroupBridgeLeftovers {

    enum UITest {
        static let profile = "grupos-repetidos"
        static let groupName = "Jurpi QA"
        static let usdExpense = "Google One"
        static let penExpense = "Gasolina"
    }

    @MainActor
    static func create(in context: ModelContext) {
        let group = SplitGroup(name: UITest.groupName, iconName: "heart", currencyCode: "PEN", isOwner: true)
        group.isBackendGroup = true
        context.insert(group)
        let zone = group.cloudKitZoneID
        let me = SplitMember(groupZoneID: zone, displayName: "Tú", cloudKitUserRecordID: "uitest-current-user",
                             role: "admin", status: .active, isGroupOwner: true, isCurrentUser: true)
        let pia = SplitMember(groupZoneID: zone, displayName: "Pia", cloudKitUserRecordID: "uitest-member-pia",
                              status: .active)
        context.insert(me)
        context.insert(pia)

        let sapphireUSD = Account(name: "Sapphire QA USD", currencyCode: "USD", colorHex: "#1F3A93",
                                  iconName: "creditcard", type: "credit")
        let sapphirePEN = Account(name: "Sapphire QA", currencyCode: "PEN", colorHex: "#1F3A93",
                                  iconName: "creditcard", type: "credit")
        context.insert(sapphireUSD)
        context.insert(sapphirePEN)

        let gastos: [(desc: String, amount: Double, currency: String, subcat: String, account: Account)] = [
            (UITest.usdExpense, 10.84, "USD", "Entretenimiento", sapphireUSD),
            (UITest.penExpense, 259.83, "PEN", "Transporte", sapphirePEN),
        ]
        var created: [(SplitExpense, Account)] = []
        for g in gastos {
            let expense = SplitExpense(groupZoneID: zone, amount: g.amount, currencyCode: g.currency,
                                       expenseDescription: g.desc, paidByMemberID: me.id.uuidString,
                                       splitType: "equal", subcategoryName: g.subcat)
            expense.date = Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now
            context.insert(expense)
            let half = ((g.amount / 2) * 100).rounded() / 100
            for m in [me, pia] {
                context.insert(SplitShare(expenseID: expense.id, memberID: m.id.uuidString, amount: half,
                                          isPaid: m === me, groupZoneID: zone))
            }
            created.append((expense, g.account))
        }
        do { try context.save() } catch {
            print("DevSeedGroupBridgeLeftovers: save error: \(error)")
            return
        }

        let bridge = GroupTransactionBridge.shared
        guard bridge.isReady else { return }
        do {
            for (expense, account) in created {
                _ = try bridge.bridgeExpense(expense, in: group, accountForCurrentUser: account,
                                             isRemoteSync: false, shouldSave: false)
            }
            try context.save()
            // La pasada ciega: las patas sin cuenta un instante, el puente remoto, y las cuentas de vuelta.
            let ids = Set(created.map { $0.0.id.uuidString })
            let legs = try context.fetch(FetchDescriptor<TransactionItem>()).filter { ids.contains($0.splitExpenseID ?? "") }
            let accounts = legs.map(\.account)
            for leg in legs { leg.account = nil }
            try context.save()
            _ = try bridge.bridgeRemoteExpenses(ids: created.map { $0.0.id })
            for (leg, account) in zip(legs, accounts) { leg.account = account }
            // Todo es «de antes» del arreglo: las patas del alta, hace dos días y una hora; lo que dejó la pasada ciega,
            // hace dos días.
            let twoDaysAgo = Date.now.addingTimeInterval(-2 * 86_400)
            let known = Set(legs.map(\.persistentModelID))
            for tx in try context.fetch(FetchDescriptor<TransactionItem>()) where ids.contains(tx.splitExpenseID ?? "") {
                tx.createdAt = known.contains(tx.persistentModelID) ? twoDaysAgo.addingTimeInterval(-3_600) : twoDaysAgo
            }
            for draft in try context.fetch(FetchDescriptor<InboxDraft>()) where ids.contains(draft.splitExpenseID ?? "") {
                draft.createdAt = twoDaysAgo
            }
            try context.save()
        } catch {
            print("DevSeedGroupBridgeLeftovers: bridge error: \(error)")
        }
    }
}
#endif

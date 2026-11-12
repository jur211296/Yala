//
//  DevSeedGroupSplitLines.swift
//  Yala
//
//  Fixture de QA de Grupos B, cards 5 y 6 (`-uitest-seed-group-split-lines`): el caso Pía del diseño acordado
//  (`docs/disenos/grupos-tu-parte-en-lineas/README.md`). En «Pía y yo», Pía paga «Recarga Sip» S/ 510 y es todo tuyo.
//
//  El gasto llega como llegaría del servidor (Pía lo apuntó) y pasa por el puente REAL con `isRemoteSync`, así que tu
//  parte queda en «Grupos» y la Bandeja pide su categoría con el borrador de siempre. La cuenta Sip es la que recibe la
//  recarga cuando se parte en 500 + 10.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedGroupSplitLines {

    /// Asideros del escenario. Deliberadamente SIN localizar: no son copy.
    static let groupName = "Pía y yo"
    static let payerName = "Pía"
    static let expenseName = "Recarga Sip"
    static let destinationAccountName = "Sip"
    static let amount: Double = 510

    @MainActor
    static func create(in context: ModelContext) {
        guard SessionState.shared.hasPrivateSession else {
            print("DevSeedGroupSplitLines: sin sesión privada el puente no crea borradores — no se siembra nada.")
            return
        }
        let name = groupName
        var existing = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.name == name })
        existing.fetchLimit = 1
        do {
            if try !context.fetch(existing).isEmpty {
                print("DevSeedGroupSplitLines: el escenario ya estaba sembrado — no se duplica.")
                return
            }
        } catch {
            print("DevSeedGroupSplitLines: Error: \(error)")
            return
        }

        let currency = CurrencyDefaults.currentPreferred
        let group = SplitGroup(name: groupName, iconName: "creditcard", currencyCode: currency, isOwner: true)
        group.isBackendGroup = true
        context.insert(group)
        let zoneID = group.cloudKitZoneID
        let me = SplitMember(groupZoneID: zoneID, displayName: "Tú", cloudKitUserRecordID: "uitest-current-user",
                             role: "admin", status: .active, isGroupOwner: true, isCurrentUser: true)
        let pia = SplitMember(groupZoneID: zoneID, displayName: payerName, cloudKitUserRecordID: "uitest-member-pia",
                              status: .active)
        context.insert(me)
        context.insert(pia)

        let sip = Account(name: destinationAccountName, currencyCode: currency, colorHex: "#0EA5E9",
                          iconName: "creditcard", type: AccountType.checking.rawValue)
        context.insert(sip)

        let expense = SplitExpense(groupZoneID: zoneID, amount: amount, currencyCode: currency,
                                   expenseDescription: expenseName, paidByMemberID: pia.id.uuidString,
                                   splitType: "exact")
        // A mediodía: lejos de la medianoche que comparten dos días.
        expense.date = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date.now) ?? Date.now
        context.insert(expense)
        context.insert(SplitShare(expenseID: expense.id, memberID: me.id.uuidString, amount: amount, isPaid: false,
                                  groupZoneID: zoneID))
        context.insert(SplitShare(expenseID: expense.id, memberID: pia.id.uuidString, amount: 0, isPaid: true,
                                  groupZoneID: zoneID))

        do {
            try context.save()
            try GroupTransactionBridge.shared.bridgeExpense(expense, in: group, isRemoteSync: true)
            SessionState.shared.incrementDataVersion()
        } catch {
            print("DevSeedGroupSplitLines: Error: \(error)")
        }
    }
}
#endif

//
//  DevSeedSettlementAmountChange.swift
//  Yala
//
//  Fixture de QA para `settlement-amount-edited-after-approval-leaves-the-bank-stale`
//  (`-uitest-seed-settlement-amount-change`): Ana me pagó 25 en el grupo «Viaje QA», lo aprobé en el Inbox a «Banco QA»,
//  y después la liquidación pasa a 30 como la deja una edición remota.
//
//  La app iOS no edita liquidaciones, así que el cambio se planta en la fila y se re-puentea por el MISMO camino que usa el
//  pull del backend (`GroupsSyncClient.applySettlement` → `bridgeRemoteSettlements`). Todo lo demás —el borrador
//  pendiente, la aprobación con su marca, la transacción real— sale de los servicios reales.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedSettlementAmountChange {

    /// Asideros del escenario. Deliberadamente SIN localizar: no son copy.
    static let groupName = "Viaje QA"
    static let accountName = "Banco QA"
    static let note = "QA liquidación"
    static let approvedAmount: Double = 25
    static let correctedAmount: Double = 30

    @MainActor
    static func create(in context: ModelContext) {
        guard SessionState.shared.hasPrivateSession else {
            print("DevSeedSettlementAmountChange: sin sesión privada el bridge no crea borradores — no se siembra nada.")
            return
        }
        let accountNameValue = accountName
        var existing = FetchDescriptor<Account>(predicate: #Predicate { $0.name == accountNameValue })
        existing.fetchLimit = 1
        do {
            if try !context.fetch(existing).isEmpty {
                print("DevSeedSettlementAmountChange: el escenario ya estaba sembrado — no se duplica.")
                return
            }
        } catch {
            print("DevSeedSettlementAmountChange: Error: \(error)")
            return
        }

        let currency = CurrencyDefaults.currentPreferred
        let group = SplitGroup(name: groupName, iconName: "airplane", currencyCode: currency, isOwner: true)
        group.isBackendGroup = true
        context.insert(group)
        let zoneID = group.cloudKitZoneID
        let me = SplitMember(groupZoneID: zoneID, displayName: "Tú", cloudKitUserRecordID: "uitest-current-user",
                             role: "admin", status: .active, isGroupOwner: true, isCurrentUser: true)
        let ana = SplitMember(groupZoneID: zoneID, displayName: "Ana", cloudKitUserRecordID: "uitest-member-ana",
                              status: .active)
        context.insert(me)
        context.insert(ana)
        let bank = Account(name: accountName, currencyCode: currency, colorHex: "#2563EB",
                           iconName: "building.columns", type: AccountType.checking.rawValue)
        context.insert(bank)
        let settlement = SplitSettlement(groupZoneID: zoneID, fromMemberID: ana.id.uuidString,
                                         toMemberID: me.id.uuidString, amount: approvedAmount,
                                         currencyCode: currency, note: note, date: Date.now)
        settlement.isConfirmed = true
        context.insert(settlement)

        do {
            try context.save()
            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [settlement.id])
            let settlementID = settlement.id.uuidString
            let pendingRaw = DraftStatus.pending.rawValue
            guard let pending = try context.fetch(FetchDescriptor<InboxDraft>(
                predicate: #Predicate { $0.splitSettlementID == settlementID && $0.statusRaw == pendingRaw })).first
            else {
                print("DevSeedSettlementAmountChange: el bridge no dejó borrador pendiente — escenario a medias.")
                return
            }
            pending.account = bank
            DraftService.shared.setContext(context)
            _ = try DraftService.shared.approveDraft(pending, currencyConverter: CurrencyConverter())

            // La edición remota: el importe cambia en la fila y el pull re-puentea.
            settlement.amount = correctedAmount
            try context.save()
            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [settlement.id])
            SessionState.shared.incrementDataVersion()
        } catch {
            print("DevSeedSettlementAmountChange: Error: \(error)")
        }
    }
}
#endif

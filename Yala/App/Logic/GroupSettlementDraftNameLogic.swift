//
//  GroupSettlementDraftNameLogic.swift
//  Yala
//
//  UX 2.2 · L13-12 (decisión B de Jürgen, 2026-10-18): el borrador de un pago de grupo no trae descripción, y la Bandeja
//  decía «Sin descripción» y la hoja un «—». Ahora tiene nombre: «Pago a Ana · Viaje a Cusco» si lo hiciste tú, «Pago de
//  Ana · Viaje a Cusco» si lo recibiste. Se calcula al pintar, así que vale también para los borradores que ya existen.
//

import Foundation
import SwiftData

enum GroupSettlementDraftNameLogic {

    /// - Parameters:
    ///   - iPaid: el pago lo hiciste tú (el borrador lleva el importe en negativo).
    ///   - counterpart: a quién le pagaste, o quién te pagó.
    ///   - group: nombre del grupo.
    static func name(iPaid: Bool, counterpart: String, group: String) -> String {
        iPaid
            ? L10n.Inbox.GroupSettlementDraft.paidTo(counterpart, group: group)
            : L10n.Inbox.GroupSettlementDraft.paidBy(counterpart, group: group)
    }
}

/// Resuelve el nombre del borrador de un pago con lo que hay en el store de Grupos. `nil` si no se puede decir sin
/// inventar: no es un pago, la liquidación o sus miembros no están, o no eres ni quien paga ni quien recibe.
enum GroupSettlementDraftNameResolver {

    static func name(for draft: InboxDraft, context: ModelContext) -> String? {
        guard draft.sourceType == .groupSettlement,
              let settlementID = draft.splitSettlementID,
              let settlementUUID = UUID(uuidString: settlementID),
              let zoneID = draft.splitGroupZoneID else { return nil }
        do {
            var settlementDescriptor = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.id == settlementUUID })
            settlementDescriptor.fetchLimit = 1
            guard let settlement = try context.fetch(settlementDescriptor).first,
                  let me = try GroupExpenseService.resolveCurrentUserMember(inZone: zoneID, context: context)
            else { return nil }
            let myID = me.id.uuidString
            let iPaid: Bool
            let counterpartID: String
            if settlement.fromMemberID == myID {
                iPaid = true
                counterpartID = settlement.toMemberID
            } else if settlement.toMemberID == myID {
                iPaid = false
                counterpartID = settlement.fromMemberID
            } else {
                return nil
            }
            guard let counterpartUUID = UUID(uuidString: counterpartID) else { return nil }
            var memberDescriptor = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.id == counterpartUUID })
            memberDescriptor.fetchLimit = 1
            guard let counterpart = try context.fetch(memberDescriptor).first else { return nil }
            var groupDescriptor = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zoneID })
            groupDescriptor.fetchLimit = 1
            let groupName = try context.fetch(groupDescriptor).first?.name ?? draft.originGroupName ?? ""
            return GroupSettlementDraftNameLogic.name(
                iPaid: iPaid, counterpart: counterpart.resolvedDisplayName, group: groupName)
        } catch {
            #if DEBUG
            print("GroupSettlementDraftNameResolver: Error: \(error)")
            #endif
            return nil
        }
    }
}

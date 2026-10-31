//
//  GroupPushNoticeBuilder.swift
//  Yala
//
//  Los textos del aviso que reciben los DEMÁS miembros cuando este teléfono sube un cambio de grupo (card sztn,
//  2026-10-30). Viajan en el body de `POST /groups/push` como `notice`, y el Worker los combina con lo que él sí sabe
//  de cada delta aplicado (`gateway/src/groups/notice.ts`) para pintar «María P. agregó Foppy Pet Store · S/ 40.60»
//  con el nombre del grupo de título.
//
//  Por qué los pone el cliente: el servidor no puede leer nombres, conceptos ni importes, que guarda cifrados at-rest.
//  Quien sube los conoce en claro en ese instante. El Worker no los guarda: van al payload de APNs y mueren ahí.
//
//  Todo es «mejor esfuerzo»: un fetch que falla deja fuera ese dato y el Worker degrada el texto (sin concepto, o el
//  genérico de siempre si falta quién o el grupo). Nunca bloquea ni retrasa la subida.
//

import Foundation
import SwiftData

@MainActor
enum GroupPushNoticeBuilder {

    /// Lo que se sabe de una fila del outbox, sin el `@Model` (para la parte pura y sus tests).
    struct Row {
        let entityType: String
        let groupID: String
        let syncID: UUID
        let isTombstone: Bool
    }

    /// El objeto `notice` del body, o `nil` si no hay nada que contar. `actorName` resuelve el nombre de quien sube en
    /// cada grupo; en producción, el miembro canónico del usuario en esa zona.
    static func notice(
        for rows: [Row],
        context: ModelContext,
        actorName: ((String, ModelContext) -> String?)? = nil
    ) -> [String: Any]? {
        // `nil` = el miembro canónico del usuario en esa zona. El default no puede ser la función: un valor por
        // defecto se evalúa fuera del main actor.
        let actorName = actorName ?? { liveActorName(inZone: $0, context: $1) }
        guard !rows.isEmpty else { return nil }
        var actors: [String: String] = [:]
        var groups: [String: String] = [:]
        var entries: [String: [String: Any]] = [:]

        for groupID in Set(rows.map(\.groupID)) {
            if let name = groupName(zoneID: groupID, context: context), !name.isEmpty { groups[groupID] = name }
            if let actor = actorName(groupID, context), !actor.isEmpty { actors[groupID] = actor }
        }

        for row in rows where !row.isTombstone {
            let key = row.syncID.uuidString.lowercased()
            switch row.entityType {
            case GroupSyncEntityType.splitExpense:
                if let expense = fetchExpense(row.syncID, context: context) {
                    entries[key] = expenseEntry(expense)
                }
            case GroupSyncEntityType.splitShare:
                guard let share = fetchShare(row.syncID, context: context) else { continue }
                let parentKey = share.expenseID.uuidString.lowercased()
                entries[key] = ["parent": parentKey]
                // El gasto de la cuota, aunque no suba en esta tanda: editar solo el reparto es editar ese gasto.
                if entries[parentKey] == nil, let expense = fetchExpense(share.expenseID, context: context) {
                    entries[parentKey] = expenseEntry(expense)
                }
            case GroupSyncEntityType.splitSettlement:
                if let settlement = fetchSettlement(row.syncID, context: context) {
                    entries[key] = [
                        "amount": YalaFormatterStatic.currency(value: settlement.amount, currencyCode: settlement.currencyCode),
                        "from": memberName(settlement.fromMemberID, context: context),
                        "to": memberName(settlement.toMemberID, context: context),
                    ].compactMapValues { $0 }
                }
            default:
                continue
            }
        }

        guard !actors.isEmpty || !groups.isEmpty || !entries.isEmpty else { return nil }
        return ["actors": actors, "groups": groups, "rows": entries]
    }

    /// El `notice` serializado para ir tal cual dentro del body (`"notice":{…}`), o `nil`.
    static func noticeJSON(_ notice: [String: Any]?) -> String? {
        guard let notice, JSONSerialization.isValidJSONObject(notice) else { return nil }
        do {
            let data = try JSONSerialization.data(withJSONObject: notice, options: [.sortedKeys])
            return String(data: data, encoding: .utf8)
        } catch {
            #if DEBUG
            print("GroupPushNoticeBuilder: Error: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Lecturas

    static func liveActorName(inZone zoneID: String, context: ModelContext) -> String? {
        do {
            return try GroupExpenseService.resolveCurrentUserMember(inZone: zoneID, context: context)?.displayName
        } catch {
            #if DEBUG
            print("GroupPushNoticeBuilder: Error resolving actor: \(error)")
            #endif
            return nil
        }
    }

    private static func expenseEntry(_ expense: SplitExpense) -> [String: Any] {
        var entry: [String: Any] = [
            "amount": YalaFormatterStatic.currency(value: expense.amount, currencyCode: expense.currencyCode),
        ]
        let concept = expense.expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !concept.isEmpty { entry["concept"] = concept }
        if expense.isOpeningBalance { entry["opening"] = true }
        return entry
    }

    private static func groupName(zoneID: String, context: ModelContext) -> String? {
        do {
            var descriptor = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zoneID })
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.name
        } catch {
            #if DEBUG
            print("GroupPushNoticeBuilder: Error fetching group: \(error)")
            #endif
            return nil
        }
    }

    private static func fetchExpense(_ id: UUID, context: ModelContext) -> SplitExpense? {
        do {
            var descriptor = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first
        } catch {
            #if DEBUG
            print("GroupPushNoticeBuilder: Error fetching expense: \(error)")
            #endif
            return nil
        }
    }

    private static func fetchShare(_ id: UUID, context: ModelContext) -> SplitShare? {
        do {
            var descriptor = FetchDescriptor<SplitShare>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first
        } catch {
            #if DEBUG
            print("GroupPushNoticeBuilder: Error fetching share: \(error)")
            #endif
            return nil
        }
    }

    private static func fetchSettlement(_ id: UUID, context: ModelContext) -> SplitSettlement? {
        do {
            var descriptor = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first
        } catch {
            #if DEBUG
            print("GroupPushNoticeBuilder: Error fetching settlement: \(error)")
            #endif
            return nil
        }
    }

    private static func memberName(_ memberID: String, context: ModelContext) -> String? {
        guard let uuid = UUID(uuidString: memberID) else { return nil }
        do {
            var descriptor = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.id == uuid })
            descriptor.fetchLimit = 1
            let name = try context.fetch(descriptor).first?.displayName
            return (name?.isEmpty ?? true) ? nil : name
        } catch {
            #if DEBUG
            print("GroupPushNoticeBuilder: Error fetching member: \(error)")
            #endif
            return nil
        }
    }
}

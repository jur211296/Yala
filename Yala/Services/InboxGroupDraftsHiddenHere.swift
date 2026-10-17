//
//  InboxGroupDraftsHiddenHere.swift
//  Yala
//
//  La lista local de gastos de grupo quitados de la Bandeja en este teléfono. Las decisiones viven en
//  `InboxGroupDraftHiddenHereLogic`. Ticket `prior-icloud-group-records-summed-without-their-group`.
//

import Foundation
import SwiftData

/// Lee y escribe la lista de gastos de grupo ocultos en este teléfono, y dice qué borradores se ven.
///
/// **No escribe ninguna fila de SwiftData, a propósito.** Todo lo que cambia una fila viaja: el espejo de iCloud lo
/// exporta y el drain del canal de la nube lo sube. La lista vive en `UserDefaults.standard` (sin prefijo de
/// preferencias sincronizadas: no pasa por `PreferenceSyncService` ni por el iCloud-KV), así que el otro dispositivo con
/// ese grupo no se entera. La retira el borrado de datos con las demás claves que salen de las filas
/// (`DataWipeService.removeRowDerivedKeys`).
@MainActor
enum InboxGroupDraftsHiddenHere {

    nonisolated static let key = "inbox.groupExpensesHiddenHere"

    /// Los gastos (`splitExpenseID`) ocultos aquí.
    static func hiddenExpenseIDs(_ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    /// Oculta en este teléfono el gasto del borrador, si se puede (`InboxGroupDraftHiddenHereLogic.canHideHere`).
    /// - Returns: si quedó oculto.
    @discardableResult
    static func hide(_ draft: InboxDraft, context: ModelContext, _ defaults: UserDefaults = .standard) -> Bool {
        let groupsHere = groupsPresentHere(for: [draft], context: context)
        let shape = self.shape(of: draft, groupsHere: groupsHere)
        guard InboxGroupDraftHiddenHereLogic.canHideHere(shape), let expenseID = shape.expenseID else { return false }
        var ids = hiddenExpenseIDs(defaults)
        ids.insert(expenseID)
        defaults.set(ids.sorted(), forKey: key)
        // El contador del Panel lee la misma lista: sin el aviso de «datos cambiados» seguiría contándolo hasta la
        // siguiente recarga. No hay ninguna fila nueva que exportar.
        SessionState.shared.incrementDataVersion()
        return true
    }

    /// Los borradores que se ven: quita los ocultos aquí. Sin nada oculto no lee nada más.
    static func visible(_ drafts: [InboxDraft], context: ModelContext, _ defaults: UserDefaults = .standard) -> [InboxDraft] {
        let hidden = hiddenExpenseIDs(defaults)
        guard !hidden.isEmpty, drafts.contains(where: { $0.sourceType == .groupExpense }) else { return drafts }
        let groupsHere = groupsPresentHere(for: drafts, context: context)
        return drafts.filter {
            !InboxGroupDraftHiddenHereLogic.isHidden(shape(of: $0, groupsHere: groupsHere), hiddenExpenseIDs: hidden)
        }
    }

    /// Los borradores de `drafts` a los que se les puede ofrecer «Quitar de aquí».
    static func hideableIDs(in drafts: [InboxDraft], context: ModelContext) -> Set<PersistentIdentifier> {
        guard drafts.contains(where: { $0.sourceType == .groupExpense && $0.status == .pending }) else { return [] }
        let groupsHere = groupsPresentHere(for: drafts, context: context)
        return Set(drafts.filter {
            InboxGroupDraftHiddenHereLogic.canHideHere(shape(of: $0, groupsHere: groupsHere))
        }.map(\.persistentModelID))
    }

    // MARK: - Piezas

    /// Qué grupos están en este teléfono: zonas con `SplitGroup` y gastos con `SplitExpense`.
    ///
    /// **Si la lectura falla, todo cuenta como presente**: nada se ofrece para ocultar y nada oculto se esconde. Con un
    /// store que no se deja leer, «no hay grupo» sería una suposición, y la dirección segura es la Bandeja de siempre.
    struct GroupsHere {
        let zoneIDs: Set<String>
        let expenseIDs: Set<String>
        let isUnreadable: Bool

        func contains(zoneID: String?, expenseID: String?) -> Bool {
            if isUnreadable { return true }
            if let zoneID, !zoneID.isEmpty, zoneIDs.contains(zoneID) { return true }
            if let expenseID, !expenseID.isEmpty, expenseIDs.contains(expenseID) { return true }
            return false
        }
    }

    /// Lee las zonas de grupo (pocas) y, de los gastos, solo los que nombran los borradores de grupo de `drafts`.
    static func groupsPresentHere(for drafts: [InboxDraft], context: ModelContext) -> GroupsHere {
        do {
            let zones = Set(try context.fetch(FetchDescriptor<SplitGroup>()).map(\.cloudKitZoneID))
            var expenses: Set<String> = []
            // Con su zona aquí ya no hace falta mirar el gasto.
            let wanted = Set(drafts.compactMap { draft -> String? in
                guard draft.sourceType == .groupExpense, !zones.contains(draft.splitGroupZoneID ?? "") else { return nil }
                return draft.splitExpenseID
            })
            for expenseID in wanted {
                guard let uuid = UUID(uuidString: expenseID) else { continue }
                if try context.fetchCount(FetchDescriptor<SplitExpense>(
                    predicate: #Predicate<SplitExpense> { $0.id == uuid })) > 0 {
                    expenses.insert(expenseID)
                }
            }
            return GroupsHere(zoneIDs: zones, expenseIDs: expenses, isUnreadable: false)
        } catch {
            #if DEBUG
            print("InboxGroupDraftsHiddenHere: lectura de grupos fallida, todo cuenta como presente: \(error)")
            #endif
            return GroupsHere(zoneIDs: [], expenseIDs: [], isUnreadable: true)
        }
    }

    private static func shape(of draft: InboxDraft, groupsHere: GroupsHere) -> InboxGroupDraftHiddenHereLogic.DraftShape {
        InboxGroupDraftHiddenHereLogic.DraftShape(
            sourceType: draft.sourceType,
            status: draft.status,
            expenseID: draft.splitExpenseID,
            groupExistsHere: groupsHere.contains(zoneID: draft.splitGroupZoneID, expenseID: draft.splitExpenseID))
    }
}

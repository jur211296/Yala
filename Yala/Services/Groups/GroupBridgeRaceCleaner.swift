//
//  GroupBridgeRaceCleaner.swift
//  Yala
//
//  M6: cleanup de drafts pendientes Caso A para los que ya existe TX cuenta real.
//
//  Race típico: device A crea expense Caso A con cuenta "BCP". Sync de grupos lleva
//  el SplitExpense a device B. Pero el sync personal de la TX cuenta real puede llegar
//  más tarde. Mientras tanto, device B crea un draft pendiente con hint contextual.
//
//  Cuando llega la TX personal vía sync, el draft queda obsoleto. Este helper detecta
//  el caso y lo borra automáticamente. Disparado por observer de `.transactionsImportedFromSync`.
//

import Foundation
import SwiftData

@MainActor
enum GroupBridgeRaceCleaner {

    /// Cleanup drafts pendientes Caso A para los que ya existe TX cuenta real.
    /// Se invoca tras cada import successful vía `.transactionsImportedFromSync`.
    ///
    /// Single-fetch + Set lookup evita N+1 (un fetch por draft).
    ///
    /// Excluye drafts `optInPersonalOnly` — representan intent del user pendiente de
    /// aprobación (crear su TX personal más tarde) y NO deben borrarse aunque ya exista
    /// una TX real con el mismo `splitExpenseID` (ej. la TX real de otro device llegó
    /// vía sync). Simétrico con la protección del bridge (`GroupTransactionBridge` ~:163).
    ///
    /// - Returns: Cantidad de drafts eliminados (para logging/telemetría).
    @discardableResult
    static func cleanupPendingDraftsWithMatchingTX(in context: ModelContext) -> Int {
        // Gate de quiescencia: borra `InboxDraft` (store personal) + `save()`; corre desde el observer
        // `.NSPersistentStoreRemoteChange`, que dispara DURANTE el import del restore. Diferir
        // (idempotente: re-corre en el próximo cambio remoto, ya quiescente).
        guard iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("GroupBridgeRaceCleaner.cleanup", "import not quiescent")
            return 0
        }
        let drafts: [InboxDraft]
        do {
            drafts = try context.fetch(FetchDescriptor<InboxDraft>(
                predicate: #Predicate {
                    $0.sourceTypeRaw == "groupExpense"
                        && $0.splitExpenseID != nil
                        && $0.optInPersonalOnly == false
                }
            ))
        } catch {
            #if DEBUG
            print("GroupBridgeRaceCleaner: fetch drafts failed: \(error)")
            #endif
            return 0
        }

        // Single fetch de todas las TXs cuenta real bridgeadas → Set para lookup O(1).
        let realTxs = (try? context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { tx in
                tx.splitExpenseID != nil && tx.account?.isSystemAccount == false
            }
        ))) ?? []
        let realTxSplitIDs = Set(realTxs.compactMap(\.splitExpenseID))

        var deleted = 0
        for draft in drafts where draft.needsUserInput.contains(DraftInputRequirement.account) {
            guard let splitID = draft.splitExpenseID, realTxSplitIDs.contains(splitID) else { continue }
            context.delete(draft)
            deleted += 1
        }

        if deleted > 0 {
            do {
                SaveBreadcrumb.willSave("GroupBridgeRaceCleaner.cleanup")
                try context.save()
                SaveBreadcrumb.didSave("GroupBridgeRaceCleaner.cleanup")
                #if DEBUG
                print("GroupBridgeRaceCleaner: removed \(deleted) stale draft(s)")
                #endif
            } catch {
                #if DEBUG
                print("GroupBridgeRaceCleaner: save after cleanup failed: \(error)")
                #endif
            }
        }
        return deleted
    }

    // MARK: - Lo que le sobra al puente: borrador «Elige cuenta» y préstamo repetido (bug del 2026-11-09)

    /// Desde cuándo actúa la limpieza AUTOMÁTICA de lo que sobra (`GroupBridgeLeftoverLogic`). Se sella la primera vez
    /// que se pide, que es el primer arranque con el arreglo: lo de antes se queda para el aviso de la Bandeja, donde la
    /// persona ve qué se quita (decisión de Jürgen, «solo lo nuevo + botón»). Es del TELÉFONO: no viaja.
    static let leftoverAutoSinceKey = "groupBridge.leftoverAutoSince"

    static func leftoverAutoSince(defaults: UserDefaults = .standard, now: Date = .now) -> Date {
        if let stamped = defaults.object(forKey: leftoverAutoSinceKey) as? Date { return stamped }
        defaults.set(now, forKey: leftoverAutoSinceKey)
        return now
    }

    /// Lo que sobra hoy, leído del store. LANZA si no puede leer: una lectura fallida no es «no sobra nada».
    struct Leftovers {
        let plan: GroupBridgeLeftoverLogic.Plan
        let drafts: [InboxDraft]
        let legs: [TransactionItem]
    }

    static func leftovers(in context: ModelContext, since: Date?) throws -> Leftovers {
        let loanIDs = try GroupBridgeSystemEntities.subcategoryIDs(roles: [.loanToGroups], context: context)[.loanToGroups] ?? []
        let legs = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID != nil && $0.splitSettlementID == nil }))
        let drafts = try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.sourceTypeRaw == "groupExpense" && $0.splitExpenseID != nil && $0.statusRaw == "pending" }))
        let plan = GroupBridgeLeftoverLogic.plan(
            legs: legs.map { tx in
                .init(expenseID: tx.splitExpenseID ?? "",
                      accountKey: tx.account?.shortcutID.uuidString,
                      accountIsSystem: tx.account?.isSystemAccount == true,
                      isLoanToGroups: tx.subcategory.map { loanIDs.contains($0.persistentModelID) } ?? false,
                      isManagedApart: GroupSplitLinesBridgeLogic.isDerivedMarker(tx.splitLinesRaw)
                          || GroupCollectedLegLogic.isCollected(tx.splitLinesRaw),
                      amount: tx.amount, currencyCode: tx.currencyCode, createdAt: tx.createdAt,
                      tiebreak: tx.syncID?.uuidString ?? "")
            },
            drafts: drafts.map { draft in
                .init(expenseID: draft.splitExpenseID, isPending: draft.status == .pending,
                      isGroupExpense: draft.sourceType == .groupExpense, isOptIn: draft.optInPersonalOnly,
                      needsAccount: draft.needsUserInput.contains(DraftInputRequirement.account),
                      createdAt: draft.createdAt)
            },
            onlyCreatedSince: since)
        return Leftovers(plan: plan, drafts: drafts, legs: legs)
    }

    /// Quita lo que sobra y guarda. Devuelve cuántos gastos se arreglaron. Las filas de la Bandeja se podan antes de
    /// borrar (crash de iOS 27 con la fila montada, `InboxRowPruneCoordinator`).
    @discardableResult
    static func removeLeftovers(in context: ModelContext, since: Date?) throws -> Int {
        let found = try leftovers(in: context, since: since)
        guard !found.plan.isEmpty else { return 0 }
        for index in found.plan.draftIndices {
            let draft = found.drafts[index]
            InboxRowPruneCoordinator.shared.pruneRow(draft.persistentModelID)
            context.delete(draft)
        }
        for index in found.plan.legIndices { context.delete(found.legs[index]) }
        // Sin `rollback()` si falla: el contexto es el compartido del arranque y se llevaría cambios ajenos sin guardar
        // (regla de `swiftdata-cloudkit.md`). Lo borrado queda pendiente y lo guarda el siguiente `save()`, que es lo que
        // se quería quitar.
        SaveBreadcrumb.willSave("GroupBridgeRaceCleaner.removeLeftovers")
        try context.save()
        SaveBreadcrumb.didSave("GroupBridgeRaceCleaner.removeLeftovers")
        SessionState.shared.incrementDataVersion()
        return found.plan.expenseIDs.count
    }

    /// La limpieza AUTOMÁTICA tras una sincronización, en los dos almacenes: la nube (`.cloudSyncAppliedRemoteChanges`) e
    /// iCloud (`.transactionsImportedFromSync`). Solo lo nuevo (`leftoverAutoSince`), y solo con el almacén quieto: borra y
    /// guarda, y en iCloud el import puede estar a medias. Difiere si no lo está: corre en la siguiente.
    ///
    /// En iCloud corre DESPUÉS de `cleanupPendingDraftsWithMatchingTX`, la limpieza de antes, que sigue igual: quita
    /// borradores sin fecha de corte (y sin mirar su estado). Lo de «solo lo nuevo» es de esta pasada, no de aquella.
    static func convergeAfterSync(in context: ModelContext) {
        let quiet: Bool
        switch StorageModeSignalRouter.quiescenceSource(mode: CloudSyncFlags.storageMode) {
        case .cloudEngine: quiet = SyncQuiescenceCoordinator.shared.isQuiescentForEngineSaves
        case .icloudImport: quiet = iCloudSyncService.shared.isImportQuiescent
        }
        do {
            let fixed = try autoRemoveLeftovers(in: context, isQuiet: quiet, since: leftoverAutoSince())
            if fixed > 0 { MetricsService.canary(.groupBridgeLeftoversRemoved, detail: "\(fixed)") }
        } catch {
            #if DEBUG
            print("GroupBridgeRaceCleaner: convergeAfterSync: Error: \(error)")
            #endif
        }
    }

    /// El cuerpo de la limpieza automática, sin los singletons: con el almacén a medias no toca nada, y nunca quita lo
    /// anterior a `since`.
    @discardableResult
    static func autoRemoveLeftovers(in context: ModelContext, isQuiet: Bool, since: Date) throws -> Int {
        guard isQuiet else {
            SaveBreadcrumb.deferred("GroupBridgeRaceCleaner.convergeAfterSync", "store not quiescent")
            return 0
        }
        return try removeLeftovers(in: context, since: since)
    }

    /// Pure-logic helper para tests sin contexto.
    /// Recibe colección de drafts + closure que indica si existe TX real para cada splitID.
    /// Devuelve los drafts que deberían eliminarse.
    /// Excluye drafts `optInPersonalOnly` (intent pendiente del user — ver doc de
    /// `cleanupPendingDraftsWithMatchingTX`).
    static func computeCleanupPlan(
        drafts: [InboxDraft],
        realTxExistsForSplitID: (String) -> Bool
    ) -> [InboxDraft] {
        drafts.filter { draft in
            guard draft.sourceType == .groupExpense,
                  !draft.optInPersonalOnly,
                  draft.needsUserInput.contains(DraftInputRequirement.account),
                  let splitID = draft.splitExpenseID
            else { return false }
            return realTxExistsForSplitID(splitID)
        }
    }
}

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
                try context.save()
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

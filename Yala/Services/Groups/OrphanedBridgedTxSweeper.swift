//
//  OrphanedBridgedTxSweeper.swift
//  Yala
//
//  Repara las transacciones y borradores puenteados cuyo gasto o liquidación de grupo YA NO EXISTE.
//
//  Por qué hace falta además del fix hacia delante: hasta el 2026-08-02 ningún canal de sync des-puenteaba
//  al aplicar un tombstone de gasto/liquidación (`GroupsSyncClient.applyExpense`/`applySettlement` y
//  `SplitSyncManager.applyRemoteDeletion`), así que el device que RECIBÍA el borrado se quedaba con la
//  `TransactionItem` viva apuntando a una fila muerta. Esas huérfanas ya están en los teléfonos: arreglar
//  el camino nuevo no las toca, y el usuario no puede tocarlas él (el puntero las manda al grupo, donde el
//  gasto ya no está). Este barrido es lo único que las saca.
//

import Foundation
import SwiftData

@MainActor
enum OrphanedBridgedTxSweeper {

    // MARK: - Decisión

    /// Qué hacer con una transacción puenteada cuyo puntero no resuelve.
    ///
    /// La DISTINCIÓN es la misma que ya usa el freeze de soft-delete
    /// (`GroupTransactionBridge.classifyForSoftDelete`: cuenta real vs cuenta virtual de sistema) y se
    /// reusa tal cual. Lo que cambia son las ACCIONES, y el porqué importa:
    ///
    /// - **Cuenta REAL → liberar los punteros, jamás borrar.** El usuario pagó de su bolsillo: el
    ///   movimiento ocurrió y el dinero salió de una cuenta suya. Borrarlo destruiría un hecho financiero
    ///   real por una inconsistencia de sincronización. Liberado queda como una transacción personal
    ///   normal, editable y borrable por él — que es justo la salida que hoy no tiene.
    /// - **Cuenta VIRTUAL de sistema → borrar.** Esa transacción no es un movimiento: es el ESPEJO del
    ///   gasto compartido en la cuenta «Grupos» («debo 10», «presté 40»). Sin el gasto detrás no
    ///   representa nada, y dejarla —intacta o liberada— es exactamente el fantasma reportado: dinero
    ///   inventado en Panel, presupuestos y reportes que el usuario no puede quitar.
    ///
    /// Aquí NO vale el criterio del freeze, que preserva la virtual intacta: el freeze corre cuando
    /// desaparece el GRUPO y sus gastos siguen siendo verdad («presté X y me deben X»). Una huérfana es
    /// un gasto que ya no existe para nadie.
    enum Action: Equatable {
        /// Nilea `splitExpenseID` / `splitSettlementID` / `splitGroupZoneID`, preservando monto, fecha,
        /// cuenta, subcategoría, nota y tags.
        case releasePointers
        /// Borra la transacción entera.
        case deleteVirtual
    }

    /// Forma mínima de una transacción para decidir sin `ModelContext`.
    struct TxShape: Equatable {
        let expensePointerIsOrphan: Bool
        let settlementPointerIsOrphan: Bool
        let accountIsSystem: Bool
        /// La zona del puente tiene un `SplitGroup` local **asentado**: existe y no está en su primer
        /// import (`initialMemberImportStartedAt == nil`).
        ///
        /// **Es el guard que impide destruir datos buenos**, y sin él el barrido es peor que el bug. Los
        /// dos stores bajan por canales INDEPENDIENTES: las `TransactionItem` llegan con el import personal
        /// (mirror de CloudKit o motor del Modo Nube) y los `SplitExpense` por el pull de Grupos. En un
        /// device recién instalado el personal puede asentarse ANTES, y entonces cada transacción puenteada
        /// parece huérfana sin serlo — borrarlas o soltarlas ahí destruiría el vínculo de todo el corpus, y
        /// al llegar el gasto el bridge crearía una transacción DUPLICADA junto a la que se acaba de
        /// soltar. Por eso «huérfana» exige evidencia de que el grupo ya está en este device y terminó de
        /// poblarse; sin ella no se toca nada y se reintenta en el próximo arranque.
        let zoneIsSettled: Bool

        init(
            expensePointerIsOrphan: Bool, settlementPointerIsOrphan: Bool, accountIsSystem: Bool,
            zoneIsSettled: Bool
        ) {
            self.expensePointerIsOrphan = expensePointerIsOrphan
            self.settlementPointerIsOrphan = settlementPointerIsOrphan
            self.accountIsSystem = accountIsSystem
            self.zoneIsSettled = zoneIsSettled
        }
    }

    /// Decisión pura. `nil` = la transacción no es huérfana (o no hay evidencia suficiente) y NO se toca.
    ///
    /// Una transacción sin cuenta (`accountIsSystem` no computable) se trata como REAL: ante la duda, la
    /// dirección segura es preservar el rastro, nunca borrar.
    static func decide(_ shape: TxShape) -> Action? {
        guard shape.zoneIsSettled else { return nil }
        guard shape.expensePointerIsOrphan || shape.settlementPointerIsOrphan else { return nil }
        switch GroupTransactionBridge.classifyForSoftDelete(
            transactionAccountIsSystem: shape.accountIsSystem
        ) {
        case .releaseRealAccountTx: return .releasePointers
        case .preserveVirtualSystemTx: return .deleteVirtual
        }
    }

    // MARK: - Barrido

    struct Outcome: Equatable {
        var released = 0
        var deleted = 0
        var draftsConverted = 0
        var draftsDeleted = 0

        var isEmpty: Bool { released == 0 && deleted == 0 && draftsConverted == 0 && draftsDeleted == 0 }
    }

    /// Recorre las transacciones y borradores puenteados, repara los que apuntan a un gasto o liquidación
    /// inexistente, y devuelve el recuento.
    ///
    /// **Idempotente por construcción**, sin sentinel: la segunda pasada no encuentra huérfanas porque la
    /// primera les quitó el puntero o las borró. No lleva sentinel a propósito — un one-shot dejaría sin
    /// cubrir cualquier camino futuro que vuelva a abrir el hueco, y el coste es un cruce de dos fetches
    /// que sale gratis en el caso dominante (sin transacciones puenteadas, cero trabajo).
    ///
    /// Sin gate del sello de dominio (`isDomainOpenForBridge`): ese gate corta la CREACIÓN del bridge, y
    /// cerrar la puerta jamás debe impedir LIMPIAR lo que ya está dentro.
    @discardableResult
    static func sweep(context: ModelContext) -> Outcome {
        var outcome = Outcome()

        let bridgedTxs: [TransactionItem]
        do {
            bridgedTxs = try context.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitExpenseID != nil || $0.splitSettlementID != nil }
            ))
        } catch {
            #if DEBUG
            print("OrphanedBridgedTxSweeper: fetch de transacciones puenteadas falló: \(error)")
            #endif
            return outcome
        }

        let bridgedDrafts: [InboxDraft]
        do {
            bridgedDrafts = try context.fetch(FetchDescriptor<InboxDraft>(
                predicate: #Predicate { $0.splitExpenseID != nil || $0.splitSettlementID != nil }
            ))
        } catch {
            #if DEBUG
            print("OrphanedBridgedTxSweeper: fetch de borradores puenteados falló: \(error)")
            #endif
            return outcome
        }

        guard !bridgedTxs.isEmpty || !bridgedDrafts.isEmpty else { return outcome }

        // Un solo fetch de cada tipo → Set para lookup O(1), en vez de un fetch por puntero.
        let liveExpenseIDs: Set<String>
        let liveSettlementIDs: Set<String>
        let settledZones: Set<String>
        do {
            liveExpenseIDs = Set(try context.fetch(FetchDescriptor<SplitExpense>()).map(\.id.uuidString))
            liveSettlementIDs = Set(try context.fetch(FetchDescriptor<SplitSettlement>()).map(\.id.uuidString))
            settledZones = Set(try context.fetch(FetchDescriptor<SplitGroup>())
                .filter { $0.initialMemberImportStartedAt == nil }
                .map(\.cloudKitZoneID))
        } catch {
            // CRÍTICO: sin la lista de filas vivas TODO puntero parecería huérfano y el barrido borraría el
            // corpus de grupos entero. Un fetch fallido aborta; el próximo arranque reintenta.
            #if DEBUG
            print("OrphanedBridgedTxSweeper: fetch de gastos/liquidaciones vivos falló: \(error)")
            #endif
            return outcome
        }

        func isOrphan(_ pointer: String?, in live: Set<String>) -> Bool {
            guard let pointer, !pointer.isEmpty else { return false }
            return !live.contains(pointer)
        }

        /// Sin `splitGroupZoneID` no hay forma de saber de qué grupo colgaba, así que no hay evidencia y
        /// no se toca. El bridge escribe siempre los dos punteros juntos, de modo que esto solo cubre
        /// filas de una versión anterior o a medio escribir — y en la duda no se destruye nada.
        func zoneIsSettled(_ zone: String?) -> Bool {
            guard let zone, !zone.isEmpty else { return false }
            return settledZones.contains(zone)
        }

        // ══ FASE 1 · CLASIFICAR, SIN MUTAR NADA ══
        //
        // Las dos fases están separadas a propósito y el orden es load-bearing: `computeFreezePlan`
        // decide si un borrador es un «puntero de clasificación redundante» preguntando si alguna de las
        // transacciones que recibe tiene su mismo `splitExpenseID`. Si se mutasen antes —`.releasePointers`
        // nilea justo ese campo y `.deleteVirtual` borra la fila— esa comparación daría `false` SIEMPRE,
        // ningún borrador caería en `draftsToDelete` y todos se convertirían a `.manual`. Aprobar uno de
        // esos convertidos inserta una `TransactionItem` NUEVA junto a la que se acaba de liberar: el gasto
        // aparecería DOS veces. Es exactamente la duplicación que `draftsToDelete` existe para evitar
        // (`GroupTransactionBridge.FreezePlan.draftsToDelete`), y convertiría este barrido en una
        // regresión respecto a no tener barrido.
        var orphanTxs: [TransactionItem] = []
        var actions: [(tx: TransactionItem, action: Action)] = []
        for tx in bridgedTxs {
            let shape = TxShape(
                expensePointerIsOrphan: isOrphan(tx.splitExpenseID, in: liveExpenseIDs),
                settlementPointerIsOrphan: isOrphan(tx.splitSettlementID, in: liveSettlementIDs),
                accountIsSystem: tx.account?.isSystemAccount == true,
                zoneIsSettled: zoneIsSettled(tx.splitGroupZoneID)
            )
            guard let action = decide(shape) else { continue }
            orphanTxs.append(tx)
            actions.append((tx, action))
        }

        let orphanDrafts = bridgedDrafts.filter {
            zoneIsSettled($0.splitGroupZoneID)
                && (isOrphan($0.splitExpenseID, in: liveExpenseIDs)
                    || isOrphan($0.splitSettlementID, in: liveSettlementIDs))
        }
        // Con los punteros TODAVÍA intactos. Mismo plan que el freeze de soft-delete: los punteros de
        // clasificación redundantes se borran y el resto pasa a `.manual` preservando lo que el usuario
        // ya había puesto.
        let draftPlan = orphanDrafts.isEmpty
            ? nil
            : GroupTransactionBridge.computeFreezePlan(transactions: orphanTxs, drafts: orphanDrafts)

        // ══ FASE 2 · APLICAR ══
        for (tx, action) in actions {
            switch action {
            case .releasePointers:
                tx.splitExpenseID = nil
                tx.splitSettlementID = nil
                tx.splitGroupZoneID = nil
                outcome.released += 1
            case .deleteVirtual:
                context.delete(tx)
                outcome.deleted += 1
            }
        }

        if let plan = draftPlan {
            let manualRaw = DraftSourceType.manual.rawValue
            for draft in plan.draftsToConvert {
                draft.sourceTypeRaw = manualRaw
                draft.splitExpenseID = nil
                draft.splitSettlementID = nil
                draft.splitGroupZoneID = nil
                draft.needsUserInput = []
                outcome.draftsConverted += 1
            }
            for draft in plan.draftsToDelete {
                context.delete(draft)
                outcome.draftsDeleted += 1
            }
        }

        guard !outcome.isEmpty else { return outcome }

        do {
            SaveBreadcrumb.willSave("OrphanedBridgedTxSweeper.sweep")
            try context.save()
            SaveBreadcrumb.didSave("OrphanedBridgedTxSweeper.sweep")
        } catch {
            #if DEBUG
            print("OrphanedBridgedTxSweeper: save falló: \(error)")
            #endif
            // El contexto queda con los cambios pendientes; el próximo arranque vuelve a barrer.
            return Outcome()
        }

        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
        // Sin PII: solo recuentos.
        MetricsService.canary(
            .bridgedTxOrphansRepaired,
            detail: "released=\(outcome.released)|deleted=\(outcome.deleted)|drafts=\(outcome.draftsConverted + outcome.draftsDeleted)")
        #if DEBUG
        print("OrphanedBridgedTxSweeper: released=\(outcome.released) deleted=\(outcome.deleted) draftsConverted=\(outcome.draftsConverted) draftsDeleted=\(outcome.draftsDeleted)")
        #endif
        return outcome
    }
}

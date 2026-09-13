//
//  GroupsBridgeRestoreConvergence.swift
//  Yala
//
//  Paso 8 del rediseño de sesiones · **tras restaurar de iCloud dentro de «Activar Yala completo», cada
//  gasto de grupo existe DOS veces en lo personal**: las filas que el bridge creó durante la etapa
//  solo-grupos y las que vuelven con el corpus restaurado, del mismo `splitExpenseID`. Esto las converge.
//
//  **Lo que se hace, y por qué por separado:**
//
//  - **Gastos → re-puentear por id**, por el camino de cada sincronización (`bridgeRemoteExpenses`). En modo
//    completo conserva la transacción REAL restaurada (preserve+update), deduplica las virtuales y retira el
//    par de solo-grupos. Los gastos que solo existieron en la etapa solo-grupos quedan con la forma del modo
//    completo: su borrador de «¿de qué cuenta salió?» es el ponerse al día que el corpus restaurado no tiene.
//  - **Liquidaciones → NO se re-puentean.** `bridgeSettlement` borra TODA transacción de la liquidación
//    antes de recrearla, reales incluidas (`GroupTransactionBridge.swift`, «Idempotency: delete previous
//    TX/Drafts»): re-puentear se llevaría los pagos que la persona registró con su cuenta en su vida
//    anterior. Lo único duplicado ahí es la pata VIRTUAL —las dos etapas crean la misma—, y se quita solo esa.
//
//  **Durable**, porque lo que se difiere siendo una intención tiene que sobrevivir al proceso: si el import de
//  CloudKit no se asienta, o la app muere, la marca sigue y el retome del arranque
//  (`AppBootstrapper.retryPendingBridges`, con su gate de store listo) lo reintenta.
//

import Foundation
import SwiftData
import os

/// La intención de converger, que sobrevive al proceso.
nonisolated enum GroupsBridgeRestoreConvergenceStore {

    static let key = "fullModeActivation.groupsConvergencePending"

    static func markPending(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }

    static func isPending(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

/// La decisión pura: qué patas de liquidación sobran, y qué gastos quedan por converger.
nonisolated enum GroupsBridgeRestoreConvergenceLogic {

    /// Una pata de liquidación, en valores planos.
    struct SettlementLeg: Equatable {
        let settlementID: String
        let isSystemAccount: Bool
        let createdAt: Date
    }

    /// Los índices de las patas que se borran. Por liquidación, de las patas de cuenta de SISTEMA se queda
    /// una —la más antigua, que es la restaurada: la de solo-grupos nació después— y el resto sobra. **Las
    /// patas de cuenta real no se borran nunca**: son el dinero que la persona movió, y aquí no se decide nada
    /// sobre él.
    static func settlementLegsToDelete(_ legs: [SettlementLeg]) -> [Int] {
        var bySettlement: [String: [Int]] = [:]
        for (index, leg) in legs.enumerated() where leg.isSystemAccount {
            bySettlement[leg.settlementID, default: []].append(index)
        }
        var toDelete: [Int] = []
        for indices in bySettlement.values where indices.count > 1 {
            let keep = indices.min { a, b in
                legs[a].createdAt == legs[b].createdAt ? a < b : legs[a].createdAt < legs[b].createdAt
            }
            toDelete.append(contentsOf: indices.filter { $0 != keep })
        }
        return toDelete.sorted()
    }

    /// Los gastos que se pidió converger y el bridge no atendió.
    static func unattended(requested: Set<UUID>, attended: Set<UUID>) -> Set<UUID> {
        requested.subtracting(attended)
    }
}

@MainActor
enum GroupsBridgeRestoreConvergence {

    private static let logger = Logger(subsystem: "com.yala", category: "CloudSync")

    /// Desde la activación, recién restaurado: espera a que el import de CloudKit se asiente —un `save()`
    /// durante un import es el SIGTRAP que el gate de quiescencia existe para evitar— y converge. Si no se
    /// asienta en el tope, lo deja para el arranque siguiente, que lo reintenta con su propio gate.
    static func runAfterActivation(context: ModelContext, defaults: UserDefaults = .standard) async {
        guard GroupsBridgeRestoreConvergenceStore.isPending(defaults) else { return }
        guard await iCloudSyncService.shared.waitForImportQuiescence(timeout: 30) else {
            logger.notice("GroupsBridgeRestoreConvergence deferred reason=importNotQuiescent")
            return
        }
        convergeIfPending(context: context, defaults: defaults)
    }

    /// Converge si la intención está puesta, y la retira solo si terminó. **Precondición del llamador:** haber
    /// probado que el store personal está listo (la quiescencia del import).
    ///
    /// Dos condiciones antes de escribir, y las dos son de seguridad, no de rendimiento:
    /// 1. **Ya hay sesión privada.** En una sesión solo-grupos el bridge borra las transacciones reales que
    ///    re-puentea; si la app murió antes de completar la activación, se espera a que se complete.
    /// 2. **El bridge está abierto** (sello de «empiezo de cero» y activación a medias, fuera).
    static func convergeIfPending(context: ModelContext, defaults: UserDefaults = .standard) {
        guard GroupsBridgeRestoreConvergenceStore.isPending(defaults) else { return }
        guard SessionState.shared.hasPrivateSession else { return }
        guard GroupTransactionBridge.isDomainOpenForBridge(defaults: defaults) else { return }
        do {
            let expenseIDs = Set(try context.fetch(FetchDescriptor<SplitExpense>()).map(\.id))
            let attended = try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: Array(expenseIDs))
            // **Lo NO atendido no se da por convergido** (review adversarial). `bridgeRemoteExpenses` devuelve
            // solo lo que atendió de verdad: un gasto cuyo member propio aún no resuelve vuelve sin tocar, y
            // retirar la intención con él dentro lo dejaría DOS veces en lo personal para siempre. Se entrega a
            // la intención durable que ya existe para eso, que lo reintenta en cada arranque con su tope de
            // intentos. Canal `.backend` porque todo grupo es hoy del backend: con `.cloudKit` el retome lo
            // clasificaría como abandonado y lo soltaría sin intentarlo.
            let unattended = GroupsBridgeRestoreConvergenceLogic.unattended(requested: expenseIDs, attended: attended)
            GroupsPendingBridgeIntent.arm(expenseIDs: unattended, settlementIDs: [], channel: .backend)
            try dedupeSettlementVirtualLegs(context: context)
            GroupsBridgeRestoreConvergenceStore.clear(defaults)
            logger.notice("GroupsBridgeRestoreConvergence done unattended=\(unattended.count, privacy: .public)")
        } catch {
            logger.notice("GroupsBridgeRestoreConvergence deferred reason=bridgeFailed")
            #if DEBUG
            print("GroupsBridgeRestoreConvergence: Error: \(error)")
            #endif
        }
    }

    private static func dedupeSettlementVirtualLegs(context: ModelContext) throws {
        let rows = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitSettlementID != nil }))
        // Una pata con la cuenta sin hidratar (ventana lazy) no entra en la decisión: no se sabe si es real.
        var candidates: [TransactionItem] = []
        var legs: [GroupsBridgeRestoreConvergenceLogic.SettlementLeg] = []
        for tx in rows {
            guard let settlementID = tx.splitSettlementID, let account = tx.account else { continue }
            candidates.append(tx)
            legs.append(.init(settlementID: settlementID, isSystemAccount: account.isSystemAccount,
                              createdAt: tx.createdAt))
        }
        let toDelete = GroupsBridgeRestoreConvergenceLogic.settlementLegsToDelete(legs)
        guard !toDelete.isEmpty else { return }
        for index in toDelete { context.delete(candidates[index]) }
        try context.save()
    }
}

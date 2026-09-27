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
//  **Salvo tras un borrado de filas que conservó los grupos** (`.importedRows`: «Restaurar → Empezar desde cero» de la
//  activación y el aviso tardío). Ese borrado se lleva TODA `TransactionItem`, reales incluidas, así que el motivo de
//  arriba no existe y sin re-puentear la cuenta de grupos cuenta lo prestado sin descontar lo ya cobrado o pagado. Lo
//  pide aparte (`markSettlementLegsPending`) y se hace AQUÍ, detrás del guard de sesión privada: en una sesión
//  solo-grupos el bridge crea la pata virtual sin el borrador de «¿de qué cuenta?», y nadie la re-puentearía después.
//  Solo las que se quedaron SIN NINGUNA pata: cualquier pata dice que alguien la re-puenteó después del borrado, y
//  hacerlo otra vez duplicaría el borrador de un pago que la persona ya aprobó (la aprobación crea la transacción real
//  SIN `splitSettlementID`, `DraftService` D7, así que no hay pata real que la delate).
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

    /// Retira la intención entera: la convergencia y, si iba con ella, el re-puente de las liquidaciones.
    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: settlementLegsKey)
    }

    /// **Las patas de liquidación también vuelven**, y solo lo pide un borrado de filas que conservó los grupos
    /// (ticket `activation-start-fresh-drops-group-settlement-legs`). Viaja con la convergencia —la consume
    /// `convergeIfPending`, con sus guards— y no por `GroupsPendingBridgeIntent`, cuyo retome no espera a la sesión
    /// privada. Se escribe ANTES de `markPending()` en los call-sites: un corte entre las dos deja esta dormida (inocua:
    /// nunca pisa una pata real), mientras que al revés la convergencia correría sin las liquidaciones.
    static let settlementLegsKey = "fullModeActivation.groupsConvergenceSettlementLegs"

    static func markSettlementLegsPending(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: settlementLegsKey)
    }

    static func isSettlementLegsPending(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: settlementLegsKey)
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

    /// Las liquidaciones confirmadas que se re-puentean tras un borrado de filas: **las que se quedaron sin ninguna
    /// pata**. Una pata, la que sea, dice que el sync la re-puenteó después del borrado: con sesión privada eso trajo un
    /// borrador, y si la persona ya lo aprobó, la transacción real que creó no lleva `splitSettlementID` (D7 de
    /// `DraftService`). Re-puentearla borraría la virtual y sacaría otro borrador del mismo pago: aprobado dos veces,
    /// cuenta doble. Las que no tienen nada son justo las que el borrado dejó así, y el bridge las crea una vez.
    static func settlementsToReBridge(confirmed: Set<UUID>, legSettlementIDs: Set<String>) -> Set<UUID> {
        confirmed.filter { !legSettlementIDs.contains($0.uuidString) }
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
            let unattendedSettlements = GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults)
                ? try reBridgeSettlementLegs(context: context) : []
            GroupsPendingBridgeIntent.arm(expenseIDs: unattended, settlementIDs: unattendedSettlements, channel: .backend)
            try dedupeSettlementVirtualLegs(context: context)
            GroupsBridgeRestoreConvergenceStore.clear(defaults)
            logger.notice("GroupsBridgeRestoreConvergence done unattended=\(unattended.count, privacy: .public) unattendedSettlements=\(unattendedSettlements.count, privacy: .public)")
        } catch {
            logger.notice("GroupsBridgeRestoreConvergence deferred reason=bridgeFailed")
            #if DEBUG
            print("GroupsBridgeRestoreConvergence: Error: \(error)")
            #endif
        }
    }

    /// Re-puentea las liquidaciones confirmadas que un borrado de filas dejó sin patas, y devuelve las que el bridge no
    /// atendió (member propio sin resolver): van a la intención durable con su tope, igual que los gastos.
    ///
    /// **Las de un grupo oculto no** (review adversarial del ticket `wipe-data-keeps-groups-but-drops-their-bridged-rows`).
    /// Un grupo borrado o retirado conserva su dominio con `isHiddenForAll`, y `bridgeSettlement`, a diferencia de
    /// `bridgeExpense`, no lo mira: re-puentearla dejaba la pata de la liquidación SIN la del gasto que la compensaba —el
    /// gasto de un grupo oculto no vuelve—, o sea una deuda fantasma en la cuenta de grupos y un borrador de un pago viejo.
    private static func reBridgeSettlementLegs(context: ModelContext) throws -> Set<UUID> {
        let hiddenZones = Set(try context.fetch(FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.isHiddenForAll })).map(\.cloudKitZoneID))
        let confirmed = Set(try context.fetch(FetchDescriptor<SplitSettlement>())
            .filter { $0.isConfirmed && !hiddenZones.contains($0.groupZoneID) }.map(\.id))
        let legSettlementIDs = Set(try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitSettlementID != nil })).compactMap(\.splitSettlementID))
        let requested = GroupsBridgeRestoreConvergenceLogic.settlementsToReBridge(
            confirmed: confirmed, legSettlementIDs: legSettlementIDs)
        guard !requested.isEmpty else { return [] }
        let attended = try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: Array(requested))
        return GroupsBridgeRestoreConvergenceLogic.unattended(requested: requested, attended: attended)
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

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
//  ── Lo que lo separa de una pérdida masiva de datos: el gate de FRESCURA del canal ─────────────────────
//  Decidir «huérfana» es decidir que un gasto NO EXISTE mirando un store que otro canal puebla. Ese guard
//  lo lleva `GroupChannelFreshnessGate` (`Yala/App/Logic/`) y consiste en exigir que el canal de la zona
//  haya AGOTADO su entrega con la zona en su alcance — pull backend `.completed` + `group_id` en el cursor,
//  o ambos engines de CloudKit con ≥1 ciclo de fetch entero y sin fallo en esa zona.
//
//  La versión anterior exigía solo `zoneIsSettled` (`SplitGroup` local con `initialMemberImportStartedAt ==
//  nil`) y **eso no prueba frescura**: nada re-arma ese marcador sobre una fila viva, así que una zona
//  conocida desde hace semanas quedaba «asentada» para siempre. Con dos teléfonos del mismo usuario y el
//  canal de Grupos parado en uno de ellos (kill-switch remoto, sesión Yala caducada, snapshot de
//  remote-config ausente), la `TransactionItem` de un gasto nuevo SÍ llega por el espejo personal mientras
//  el `SplitExpense` no llega por ningún lado ⇒ el barrido la borraba o la soltaba, y esas mutaciones se
//  exportaban de vuelta, llevándose la transacción del device que sí tenía el gasto. El gate viejo sigue
//  dentro del nuevo como su primer escalón, así que el caso que SÍ cubría —device recién instalado cuyo
//  import personal se asienta antes del pull— sigue cubierto.
//
//  ── El conjunto de CANDIDATAS: solo las zonas del canal backend (A2 · iii, 2026-08-06) ─────────────────
//  El gate sigue siendo el de arriba y sigue siendo el mismo para los dos consumidores. Lo que se acotó es
//  a QUIÉN se le pregunta: una transacción cuya zona no pertenece al canal backend ya no es candidata, y
//  por tanto ni se repara ni cuenta para el canario. La razón es que su evidencia venía del brazo CloudKit
//  del adaptador, y la Fase 3 lo deja sin fuente al borrar `SplitSyncManager`. Las alternativas eran
//  peores: concederles frescura a ciegas es la dirección que DESTRUYE (un device recién instalado tomaría
//  todo su corpus puenteado por huérfano), y negarla con constantes `false` haría que
//  `bridgedTxOrphanSweepDeferred` se emitiera en todos los arranques con candidatas, quemando la única
//  superficie de observación del subsistema. **Precio, dicho para que nadie lo redescubra:** las huérfanas
//  de zonas legacy dejan de repararse y se pierde la señal de cuántas hay. El owner lo aceptó el
//  2026-08-04 con el §1 del plan cancelado: no hay grupos CloudKit legacy útiles en ningún usuario.
//  La rama CloudKit de `GroupChannelFreshnessGate` NO se toca — sigue siendo la decisión pura correcta y
//  el editor (`NewTransactionView.resolveBridgedPointer`) la sigue consumiendo.
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
        /// El canal de la zona del puente **agotó su entrega** y esta zona estaba en su alcance
        /// (`GroupChannelFreshnessGate.evaluate(...) == .fresh`).
        ///
        /// **Es el guard que impide destruir datos buenos**, y sin él el barrido es peor que el bug. Los
        /// dos stores bajan por canales INDEPENDIENTES: las `TransactionItem` llegan con el import personal
        /// (mirror de CloudKit o motor del Modo Nube) y los `SplitExpense` por el pull de Grupos. Sin
        /// evidencia de que el canal de Grupos habló, cada transacción puenteada cuyo gasto no ha bajado
        /// TODAVÍA parece huérfana sin serlo — borrarlas o soltarlas ahí destruye el vínculo, y esas
        /// mutaciones se exportan por el espejo personal, así que el daño llega al device que SÍ tiene el
        /// gasto; al bajar por fin, el bridge crea un draft Caso A y aprobarlo DUPLICA el gasto.
        ///
        /// Antes esto era `zoneIsSettled` —`SplitGroup` local con `initialMemberImportStartedAt == nil`— y
        /// **eso es un marcador de PRIMER import, no una prueba de frescura**: nada lo re-arma sobre una
        /// fila viva, así que una zona conocida desde hace semanas quedaba «asentada» para siempre, con el
        /// canal apagado (kill-switch, sesión caducada, snapshot de remote-config ausente) o rezagado. El
        /// criterio nuevo lo CONTIENE (`zoneHasSettledGroup` sigue siendo el primer guard) y le añade la
        /// frescura del canal. Ver `GroupChannelFreshnessGate`.
        let zoneEvidenceIsFresh: Bool

        init(
            expensePointerIsOrphan: Bool, settlementPointerIsOrphan: Bool, accountIsSystem: Bool,
            zoneEvidenceIsFresh: Bool
        ) {
            self.expensePointerIsOrphan = expensePointerIsOrphan
            self.settlementPointerIsOrphan = settlementPointerIsOrphan
            self.accountIsSystem = accountIsSystem
            self.zoneEvidenceIsFresh = zoneEvidenceIsFresh
        }
    }

    /// Decisión pura. `nil` = la transacción no es huérfana (o no hay evidencia suficiente) y NO se toca.
    ///
    /// Una transacción sin cuenta (`accountIsSystem` no computable) se trata como REAL: ante la duda, la
    /// dirección segura es preservar el rastro, nunca borrar.
    static func decide(_ shape: TxShape) -> Action? {
        guard shape.zoneEvidenceIsFresh else { return nil }
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
    ///
    /// `signals` existe para los tests: el estado de sesión de los dos canales vive en singletons y se
    /// filtraría de un test al siguiente. Producción usa `.live` y no pasa el parámetro.
    @discardableResult
    static func sweep(
        context: ModelContext,
        signals: GroupChannelFreshness.ChannelSignals? = nil
    ) -> Outcome {
        let signals = signals ?? .live()
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
        do {
            liveExpenseIDs = Set(try context.fetch(FetchDescriptor<SplitExpense>()).map(\.id.uuidString))
            liveSettlementIDs = Set(try context.fetch(FetchDescriptor<SplitSettlement>()).map(\.id.uuidString))
        } catch {
            // CRÍTICO: sin la lista de filas vivas TODO puntero parecería huérfano y el barrido borraría el
            // corpus de grupos entero. Un fetch fallido aborta; el próximo arranque reintenta.
            #if DEBUG
            print("OrphanedBridgedTxSweeper: fetch de gastos/liquidaciones vivos falló: \(error)")
            #endif
            return outcome
        }

        // Veredicto POR ZONA de los dos canales, en el instante de decidir. Un solo fetch de grupos y uno
        // del cursor del pull. Una zona ausente del mapa (sin `SplitGroup` local) NO es fresca.
        let verdicts = GroupChannelFreshness.verdictsByZone(context: context, signals: signals)
        // Motivos por los que se dejó una candidata sin tocar. Solo se cuentan las que el guard viejo
        // habría barrido, para que el canario signifique «el gate está frenando algo» y no «hoy no había
        // huérfanas»: sin esa distinción, un gate clavado —un canal apagado durante semanas— sería
        // indistinguible del caso sano y silencioso. Y desde A2·(iii) solo se cuentan las de zonas del
        // canal BACKEND: las legacy no son candidatas, así que contarlas convertiría el canario en un
        // censo permanente y le quitaría exactamente el significado que existe para tener.
        var deferredByVerdict: [GroupChannelFreshnessGate.Verdict: Int] = [:]

        func isOrphan(_ pointer: String?, in live: Set<String>) -> Bool {
            guard let pointer, !pointer.isEmpty else { return false }
            return !live.contains(pointer)
        }

        /// ¿Entra esta zona en el conjunto de candidatas, y con evidencia suficiente para actuar?
        ///
        /// Sin `splitGroupZoneID`, o sin `SplitGroup` local de esa zona, no hay forma de saber de qué grupo
        /// colgaba ni a qué canal preguntarle: no hay evidencia y no se toca, pero SÍ cuenta para el
        /// canario — es el caso «todavía no ha bajado», que es justo lo que hay que poder ver. El bridge
        /// escribe siempre los dos punteros juntos, de modo que la rama de zona vacía solo cubre filas de
        /// una versión anterior o a medio escribir, y en la duda no se destruye nada.
        ///
        /// **A2 · dirección (iii): una zona FUERA del canal backend no es candidata.** Su evidencia sería
        /// la del brazo CloudKit, que la Fase 3 deja sin fuente al borrar `SplitSyncManager`, y las dos
        /// alternativas son peores: concederla a ciegas es la dirección que destruye datos, y negarla con
        /// constantes `false` emitiría `bridgedTxOrphanSweepDeferred` en TODOS los arranques con
        /// candidatas, con lo que el canario dejaría de significar «el gate está frenando algo» y el
        /// subsistema se quedaría sin su única superficie de observación. Sacándolas del conjunto, el
        /// canario conserva su significado para las zonas del canal vivo. **El precio, declarado:** las
        /// huérfanas de zonas legacy dejan de repararse, y en silencio.
        func zoneIsSweepable(_ zone: String?, pointerIsOrphan: Bool) -> Bool {
            guard let zone, !zone.isEmpty, let status = verdicts[zone] else {
                if pointerIsOrphan { deferredByVerdict[.noSettledGroup, default: 0] += 1 }
                return false
            }
            guard status.belongsToBackendChannel else { return false }
            if pointerIsOrphan, !status.verdict.isFresh { deferredByVerdict[status.verdict, default: 0] += 1 }
            return status.verdict.isFresh
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
            let expenseIsOrphan = isOrphan(tx.splitExpenseID, in: liveExpenseIDs)
            let settlementIsOrphan = isOrphan(tx.splitSettlementID, in: liveSettlementIDs)
            let shape = TxShape(
                expensePointerIsOrphan: expenseIsOrphan,
                settlementPointerIsOrphan: settlementIsOrphan,
                accountIsSystem: tx.account?.isSystemAccount == true,
                zoneEvidenceIsFresh: zoneIsSweepable(
                    tx.splitGroupZoneID, pointerIsOrphan: expenseIsOrphan || settlementIsOrphan)
            )
            guard let action = decide(shape) else { continue }
            orphanTxs.append(tx)
            actions.append((tx, action))
        }

        let orphanDrafts = bridgedDrafts.filter { draft in
            let pointerIsOrphan = isOrphan(draft.splitExpenseID, in: liveExpenseIDs)
                || isOrphan(draft.splitSettlementID, in: liveSettlementIDs)
            return zoneIsSweepable(draft.splitGroupZoneID, pointerIsOrphan: pointerIsOrphan)
                && pointerIsOrphan
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

        // ANTES del early-return: el caso que hay que poder ver en el dashboard es justo aquel en que el
        // barrido no hizo NADA porque el gate lo frenó. Sin esta emisión, un canal apagado durante semanas
        // —o un engine de CloudKit que nunca cierre su ciclo, que es el coste asumido de exigir los dos—
        // se lee igual que «no había huérfanas»: `bridgedTxOrphansRepaired` en cero, y ni una señal de que
        // hay candidatas esperando. Sin PII: recuentos y el motivo del veredicto.
        if !deferredByVerdict.isEmpty {
            let detail = deferredByVerdict
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: "|")
            MetricsService.canary(.bridgedTxOrphanSweepDeferred, detail: detail)
            #if DEBUG
            print("OrphanedBridgedTxSweeper: candidatas sin evidencia del canal — \(detail)")
            #endif
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

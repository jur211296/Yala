//
//  LegacyGroupsRetirement.swift
//  Yala
//
//  Retira los grupos de la era CloudKit: los oculta y suelta el puente personal que colgaba de ellos.
//
//  ── El porqué ──────────────────────────────────────────────────────────────────────────────────────────
//  Un grupo legacy es hoy un zombi PLENAMENTE ESCRIBIBLE: se le pueden crear gastos, editarlos, liquidar y
//  archivar sin una sola señal, y lo único que avisa es invitar. Su transporte murió con la Fase 3
//  (`grep 'CKSyncEngine(' Yala/` = 0), así que nada de lo que se escriba ahí sale del móvil ni llega a
//  nadie. Y ya no puede nacer ninguno más: C4 (`ad291c7f`) mató la rama `.cloudKit` de
//  `GroupCreateRoutingLogic` y borró `GroupService.createGroup`, que era su único productor de producción
//  — por eso este barrido puede correr sin llevarse un grupo creado esta semana.
//
//  ── El predicado: ANY-row por ZONA, jamás por fila ─────────────────────────────────────────────────────
//  «Legacy» = la NEGACIÓN de `GroupBackendIdentityLogic.belongsToBackendChannel` (`isBackendGroup ||
//  movedToBackendAt != nil`, `:63-65`) evaluada sobre TODAS las filas de la zona, vía la primitiva ANY-row
//  `GroupZoneCacheGate.belongsToBackendChannel(rowsInZone:)` (`:89-96`). Por fila se lleva por delante dos
//  cosas reales: la copia CONGELADA de un grupo migrado y la gemela legacy de un `SplitGroup` DUPLICADO
//  mixto (`SplitGroupDeduplicationService` documenta el estado; el duplicado nace mixto cuando el canal
//  CloudKit insertaba una gemela sin `isBackendGroup`). Es el mismo cuantificador, y por la misma razón,
//  que usan `GroupZoneCacheGate` y `GroupChannelFreshness`.
//
//  **Sin gate de frescura del canal, y no por descuido.** El barrido de huérfanas
//  (`OrphanedBridgedTxSweeper`) pregunta «¿este gasto NO EXISTE?», que es una afirmación sobre lo que un
//  canal todavía podría entregar. Aquí la pregunta es «¿esta zona pertenece a algún canal vivo?», y eso es
//  estable: un grupo del backend lleva `isBackendGroup = true` desde el INSTANTE en que su fila existe —
//  `GroupsSyncClient.applyGroupMeta` lo pone en la rama born-remote (`:2514`) y lo flipea en TODAS las
//  filas de la zona al adoptar (`:2538`), y `GroupBackendMembershipService.createGroup` lo pone antes de
//  insertar (`:120`) — así que no hay ventana en la que un grupo backend se lea legacy. Un device recién
//  instalado tiene el store de Grupos VACÍO (`cloudKitDatabase: .none`) ⇒ cero zonas ⇒ cero trabajo.
//
//  ── Las CINCO polaridades de limpieza del puente, y por qué esta es la del BARREDOR ────────────────────
//  | Mecánica                                       | TX de cuenta REAL | Espejo VIRTUAL (sistema) |
//  |------------------------------------------------|-------------------|--------------------------|
//  | `GroupTransactionBridge.freezeForSoftDelete`    | libera            | CONSERVA INTACTA         |
//  | `OrphanedBridgedTxSweeper`                      | libera            | BORRA                    |
//  | `unbridgeExpense` / `unbridgeSettlement`        | BORRA             | BORRA                    |
//  | `unbridgeDeletedRemotely`                       | BORRA             | BORRA                    |
//  | `BridgeDeactivationSheet.deleteBridgedTransactions` | **BORRA**     | **CONSERVA**             |
//
//  Se elige la SEGUNDA: cuenta real → liberar los tres punteros; espejo virtual de sistema → borrar la
//  fila. Y la razón no es de gusto:
//
//   - **El freeze deja fantasmas PERMANENTES aquí, y no es recuperable.** Conserva el espejo virtual
//     intacto porque su caso es «desaparece el GRUPO pero sus gastos siguen siendo verdad»; en una zona
//     legacy nadie va a poder limpiarlos después, porque `OrphanedBridgedTxSweeper.zoneIsSweepable` corta
//     con `guard status.belongsToBackendChannel` (`:259`) ANTES de mirar la frescura, y ese guard es hoy lo
//     único que impide que el barrido destruya las puenteadas de las zonas sin canal. El propio fichero
//     declara ese precio en `:38-40`. Un «presté 40» inventado en Panel, presupuestos y reportes, para
//     siempre y sin canario.
//   - **Las tres mecánicas destructivas están PROHIBIDAS en este camino**: `unbridge*` borra la
//     `TransactionItem` de cuenta REAL, que es dinero que salió de verdad de una cuenta del usuario. Y
//     `BridgeDeactivationSheet.deleteBridgedTransactions` (`:173-175`, `for tx in txs where
//     tx.account?.isSystemAccount == false { delete }`) es la INVERSA EXACTA del barredor —se lleva el
//     dinero real y se queda el fantasma—, o sea el peor de los cinco resultados. Un source-scan prohíbe
//     esos cuatro símbolos en este fichero (`LegacyGroupsRetirementWiringTests`).
//   - **`account == nil` se trata como REAL** (conservar), por `classifyForSoftDelete`, que es el
//     clasificador COMPARTIDO. Hay que decirlo porque las dos mecánicas existentes discrepan justo ahí: el
//     freeze inlinea el predicado con la polaridad invertida (`== false` en `GroupTransactionBridge:1405`)
//     y conserva, y el barredor libera (`:283`). Ante la duda, preservar el rastro.
//
//  ── La fila `SplitGroup` se CONSERVA (oculta), jamás se borra ──────────────────────────────────────────
//  Borrarla parece la limpieza obvia y es exactamente lo que ATRAPA el dinero: sin filas de la zona,
//  `zoneHasSettledGroup` es `false` (`GroupChannelFreshness:144`) ⇒ el gate devuelve `.noSettledGroup`
//  (`GroupChannelFreshnessGate:126`) ⇒ `NewTransactionView.resolveBridgedPointer` calcula
//  `bridgedPointerResolves = true` (`:174-175`) ⇒ **Borrar y Duplicar DESHABILITADOS** sobre un gasto que
//  ya no existe, con un banner que ofrece abrir un grupo vacío. Es el bug
//  `qa_groups-tx-fantasma-al-borrar-gasto-de-grupo` por la puerta de atrás. Conservada, el usuario recupera
//  las dos acciones.
//
//  Y ocultar es seguro HACIA FUERA: el drain solo traduce una fila cuyo `group_id` esté en
//  `backendGroupZoneIDs` (`GroupsSyncClient:721`, predicado `isBackendGroup == true`; guard en `:800`,
//  `:812` y `:865`) ⇒ en una zona legacy el flip de `is_hidden_for_all` **no sale del móvil**. El otro
//  canal que lo propagaba no existe: `CKShareCustomKey.isHiddenForAll` no tiene ni un lector.
//
//  ── Dos fases, y el orden es load-bearing ──────────────────────────────────────────────────────────────
//  Igual que en el barredor: `computeFreezePlan` decide si un borrador es un «puntero de clasificación
//  redundante» comparando su `splitExpenseID` contra las TX que recibe. Calculado DESPUÉS de mutar —
//  `.releasePointers` nilea justo ese campo y `.deleteVirtual` borra la fila— la comparación da `false`
//  siempre ⇒ `draftsToDelete` vacío ⇒ todos a `.manual` ⇒ aprobar uno inserta una `TransactionItem` NUEVA
//  junto a la recién liberada: **gasto DUPLICADO**, y una regresión respecto a no tener barrido.
//
//  ── Idempotente y sin sentinel, molde `OrphanedBridgedTxSweeper` ───────────────────────────────────────
//  La segunda pasada no encuentra nada: las TX de la zona quedaron sin `splitGroupZoneID` (o borradas) y
//  las filas ya están ocultas, así que el `Outcome` sale vacío y no hay `save()`. Sin sentinel a propósito:
//  es también la red de la zona que un fetch fallido dejó fuera esta vez, y del legacy que aparezca en un
//  device restaurado de backup mañana.
//
//  **No compite con el barrido de huérfanas y por eso no hay orden entre los dos Tasks del arranque**: los
//  conjuntos de zonas son DISJUNTOS por construcción — aquel solo actúa sobre zonas del canal backend
//  (`guard status.belongsToBackendChannel`) y este solo sobre las que NO lo son.
//

import Foundation
import SwiftData

@MainActor
enum LegacyGroupsRetirement {

    // MARK: - Decisión

    /// Qué hacer con una transacción puenteada de un grupo que se retira.
    ///
    /// **Es la polaridad del BARREDOR, no la del freeze**, y el porqué está en la cabecera: en una zona
    /// legacy nadie podrá limpiar después el espejo virtual que el freeze conservaría.
    enum Action: Equatable {
        /// Nilea `splitExpenseID` / `splitSettlementID` / `splitGroupZoneID`, preservando monto, fecha,
        /// cuenta, subcategoría, nota y tags. El dinero salió de una cuenta REAL del usuario: queda como
        /// transacción personal normal, editable y borrable — la salida que hoy no tiene.
        case releasePointers
        /// Borra la fila. No es un movimiento: es el ESPEJO del gasto compartido en la cuenta de sistema
        /// («debo 10», «presté 40»). Sin grupo detrás no representa nada y conservarlo ES el fantasma.
        case deleteVirtual
    }

    /// Forma mínima de una transacción para decidir sin `ModelContext`.
    struct TxShape: Equatable {
        /// La ZONA del puente no pertenece a ningún canal vivo (ANY-row, ver cabecera).
        let zoneIsLegacy: Bool
        /// `tx.account?.isSystemAccount == true`. Un `account` ausente da `false` ⇒ se trata como REAL.
        let accountIsSystem: Bool
    }

    /// Decisión pura. `nil` = no se toca.
    ///
    /// Delega en `GroupTransactionBridge.classifyForSoftDelete`, el clasificador COMPARTIDO, a propósito:
    /// resolver «real vs espejo» con una regla propia es el anti-patrón que este subsistema lleva media
    /// docena de fixes persiguiendo. Lo que cambia respecto del freeze son las ACCIONES, no la
    /// clasificación.
    static func decide(_ shape: TxShape) -> Action? {
        guard shape.zoneIsLegacy else { return nil }
        switch GroupTransactionBridge.classifyForSoftDelete(
            transactionAccountIsSystem: shape.accountIsSystem
        ) {
        case .releaseRealAccountTx: return .releasePointers
        case .preserveVirtualSystemTx: return .deleteVirtual
        }
    }

    /// Zonas SIN canal vivo → todas sus filas `SplitGroup`, con un solo fetch.
    ///
    /// **FALLA CERRADO**: un fetch que lanza devuelve vacío ⇒ no se retira nada y se reintenta en el
    /// próximo arranque. Perder una retirada es reversible; ocultar un grupo vivo y soltar su puente no.
    static func legacyZones(context: ModelContext) -> [String: [SplitGroup]] {
        let rows: [SplitGroup]
        do {
            rows = try context.fetch(FetchDescriptor<SplitGroup>())
        } catch {
            #if DEBUG
            print("LegacyGroupsRetirement: fetch de grupos falló — ninguna zona se retira: \(error)")
            #endif
            return [:]
        }

        var byZone: [String: [SplitGroup]] = [:]
        for row in rows where !row.cloudKitZoneID.isEmpty {
            byZone[row.cloudKitZoneID, default: []].append(row)
        }
        return byZone.filter { _, zoneRows in
            !GroupZoneCacheGate.belongsToBackendChannel(
                rowsInZone: zoneRows.map { row in
                    (isBackendGroup: row.isBackendGroup, movedToBackendAt: row.movedToBackendAt)
                })
        }
    }

    // MARK: - Barrido

    struct Outcome: Equatable {
        var groupsHidden = 0
        var released = 0
        var deleted = 0
        var draftsConverted = 0
        var draftsDeleted = 0

        var isEmpty: Bool {
            groupsHidden == 0 && released == 0 && deleted == 0
                && draftsConverted == 0 && draftsDeleted == 0
        }
    }

    /// Plan de UNA zona, calculado sin mutar nada (fase 1).
    private struct ZonePlan {
        let rows: [SplitGroup]
        let txActions: [(tx: TransactionItem, action: Action)]
        let freeze: GroupTransactionBridge.FreezePlan?
        /// `.groupScheduledExpense` — el TERCER tipo de borrador de grupo, que `computeFreezePlan` no mira
        /// (su bucle solo acepta `groupExpense`/`groupSettlement`) y que sin esto sobreviviría apuntando a
        /// una zona muerta. Su pago planificado ya queda pausado por `GroupScheduledPaymentGate` en cuanto
        /// el grupo está oculto, así que no nacen más.
        let scheduledDrafts: [InboxDraft]
    }

    /// Oculta los grupos sin canal vivo y suelta su puente personal. Devuelve el recuento.
    @discardableResult
    static func retire(context: ModelContext) -> Outcome {
        var outcome = Outcome()

        let zones = legacyZones(context: context)
        guard !zones.isEmpty else { return outcome }

        let scheduledRaw = DraftSourceType.groupScheduledExpense.rawValue

        // ══ FASE 1 · CLASIFICAR, SIN MUTAR NADA ══ (ver cabecera: mutar antes duplica gastos)
        var plans: [ZonePlan] = []
        for zoneID in zones.keys.sorted() {
            guard let rows = zones[zoneID] else { continue }

            let txs: [TransactionItem]
            let drafts: [InboxDraft]
            do {
                // `#Predicate` CONCRETO por tipo y por IGUALDAD EXACTA sobre el opcional: la misma forma
                // que `freezeForSoftDelete(zoneID:)`, que es el único patrón probado en device sobre estos
                // campos.
                txs = try context.fetch(FetchDescriptor<TransactionItem>(
                    predicate: #Predicate { $0.splitGroupZoneID == zoneID }))
                drafts = try context.fetch(FetchDescriptor<InboxDraft>(
                    predicate: #Predicate { $0.splitGroupZoneID == zoneID }))
            } catch {
                // FALLA CERRADO POR ZONA: sin saber qué cuelga de ella no se oculta ni se toca nada — el
                // grupo sigue visible y el próximo arranque reintenta. Ocultarlo sin soltar el puente
                // dejaría las TX colgando de una zona invisible, que es el fantasma.
                #if DEBUG
                print("LegacyGroupsRetirement: fetch de la zona \(zoneID) falló — se salta: \(error)")
                #endif
                continue
            }

            let txActions: [(tx: TransactionItem, action: Action)] = txs.compactMap { tx in
                let shape = TxShape(
                    zoneIsLegacy: true, accountIsSystem: tx.account?.isSystemAccount == true)
                guard let action = decide(shape) else { return nil }
                return (tx, action)
            }
            // Con los punteros TODAVÍA intactos.
            let freeze = drafts.isEmpty
                ? nil
                : GroupTransactionBridge.computeFreezePlan(transactions: txs, drafts: drafts)

            plans.append(ZonePlan(
                rows: rows,
                txActions: txActions,
                freeze: freeze,
                scheduledDrafts: drafts.filter { $0.sourceTypeRaw == scheduledRaw }))
        }

        // ══ FASE 2 · APLICAR ══
        let manualRaw = DraftSourceType.manual.rawValue
        for plan in plans {
            for (tx, action) in plan.txActions {
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

            if let freeze = plan.freeze {
                // `txsToRelease` del plan NO se usa: la liberación la decide `decide(_:)`, que además cubre
                // la mitad destructiva del espejo virtual. Del plan solo interesan los borradores.
                for draft in freeze.draftsToConvert {
                    convertToManual(draft, manualRaw: manualRaw)
                    outcome.draftsConverted += 1
                }
                for draft in freeze.draftsToDelete {
                    context.delete(draft)
                    outcome.draftsDeleted += 1
                }
            }
            for draft in plan.scheduledDrafts {
                convertToManual(draft, manualRaw: manualRaw)
                outcome.draftsConverted += 1
            }

            for row in plan.rows where !row.isHiddenForAll {
                row.isHiddenForAll = true
                outcome.groupsHidden += 1
            }
        }

        guard !outcome.isEmpty else { return outcome }

        do {
            SaveBreadcrumb.willSave("LegacyGroupsRetirement.retire")
            try context.save()
            SaveBreadcrumb.didSave("LegacyGroupsRetirement.retire")
        } catch {
            #if DEBUG
            print("LegacyGroupsRetirement: save falló: \(error)")
            #endif
            // El contexto queda con los cambios pendientes; el próximo arranque vuelve a retirar.
            return Outcome()
        }

        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
        // Sin PII: solo recuentos.
        MetricsService.canary(
            .legacyGroupsRetired,
            detail: "groups=\(outcome.groupsHidden)|released=\(outcome.released)|deleted=\(outcome.deleted)|drafts=\(outcome.draftsConverted + outcome.draftsDeleted)")
        #if DEBUG
        print("LegacyGroupsRetirement: groups=\(outcome.groupsHidden) released=\(outcome.released) deleted=\(outcome.deleted) draftsConverted=\(outcome.draftsConverted) draftsDeleted=\(outcome.draftsDeleted)")
        #endif
        return outcome
    }

    /// Un borrador de grupo pasa a `.manual` preservando lo que el usuario ya había puesto (monto, fecha,
    /// cuenta, subcategoría, tags). Mismo cuerpo que la conversión del freeze.
    private static func convertToManual(_ draft: InboxDraft, manualRaw: String) {
        draft.sourceTypeRaw = manualRaw
        draft.splitExpenseID = nil
        draft.splitSettlementID = nil
        draft.splitGroupZoneID = nil
        draft.needsUserInput = []
    }
}

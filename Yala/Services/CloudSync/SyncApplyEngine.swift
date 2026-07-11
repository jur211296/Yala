//
//  SyncApplyEngine.swift
//  Yala
//
//  Consumidor del pull: aplica los deltas remotos al store local (Modo Nube, incremento I8f-1). Es el
//  código MÁS DELICADO del motor (muta el store con datos remotos), por eso vive como EXTENSIÓN de
//  `CloudSyncEngine` — comparte `saveWithAuthor`/`loadOrCreateCursor`/el reloj (D-3) sin exponer más
//  internals. Referencias de diseño: §d.6 (pull/cursor/quarantine), §d.4bis (unidades), §d.4 (delete-
//  vs-upsert), D-0..D-9 del plan I8f-1 + fixes F-1..F-10 del review adversarial.
//
//  INVARIANTES DUROS:
//   - **D-2/F-1 (anti-laundering)**: el invariante real es "drain SÍNCRONO inmediatamente antes de CADA
//     `applyPage`" — no basta drenar al entrar: una edición del usuario que aterrice durante la
//     suspensión del `await client.pull(...)` quedaría sin drenar y el apply la machacaría (y el próximo
//     drain relee el modelo vivo y LAVA el valor remoto bajo un HLC local fresco). Por eso el loop llama
//     `drainOnce` tras recibir cada página y ANTES de `applyPage`, ambos síncronos en MainActor sin
//     `await` entre medio → todo edit de la ventana produce su fila de outbox y el guard D-1 lo protege.
//   - **D-0 (full-row)**: el pull es FULL-ROW; el apply es materialización full-row con SKIP por-unidad.
//   - **D-1 (LWW por-unidad vs OUTBOX PENDIENTE)**: la única fuente de escrituras locales que el server
//     aún no conoce es `SyncOutbox` (filas VIVAS, `rejectedReason == nil`). Una unidad remota se SALTA si
//     una fila pendiente de ese `syncID` tiene `fieldHlcs[unit] >= remote` (comparación `HLC` estructurada).
//     Un tombstone se SALTA si un upsert pendiente tiene `hlc > deleted_hlc`.
//   - **D-4**: todo se escribe bajo `author = outboxSaveAuthor` (echo-suppression del drain).
//   - **D-5/F-3 (cursor atómico + cero-descartes + rollback)**: por página, aplicar TODOS los deltas +
//     cuarentenar + `clock` persist + `serverSeqCursor = max` en UN `saveWithAuthor`. TODO delta o se
//     aplica al @Model o va a `SyncQuarantine` — no hay tercer camino. Si el save FALLA, `rollback()`
//     obligatorio: dejar el contexto sucio con el grafo remoto haría que un autosave posterior lo
//     flusheara bajo un autor NO-motor → laundering.
//   - **F-2 (refs colgadas)**: un `_ref` singular sin destino local se registra en `SyncDanglingRef`
//     (durable, en el save de página); el pase de re-resolución al final de `pullAndApplyOnce` lo cura.
//

import Foundation
import SwiftData

// MARK: - PullApplyOutcome

/// Resultado de un ciclo `pullAndApplyOnce` (cero silencios). `pagesApplied` = páginas aplicadas
/// DURABLEMENTE antes de terminar (un `.transient` a mitad NO pierde lo ya aplicado: cursor avanzó).
enum PullApplyOutcome: Equatable {
    /// Se drenó y se pulleó hasta agotar la cola (o el tope de páginas).
    case completed(pagesApplied: Int)
    /// Había un drain EN CURSO → se abortó sin aplicar (D-2). Defensivo: `drainOnce` es síncrono en
    /// MainActor, así que hoy es INALCANZABLE desde producción — queda como red si el drain gana
    /// suspensión en el futuro.
    case busy
    /// 401 en alguna página (sesión) → reintentar tras re-login. Lo aplicado antes queda durable.
    case sessionExpired
    /// 403 (cuenta suspendida/deshabilitada).
    case accountUnavailable
    /// Fallo transitorio (red/HTTP/decode/save de página) → reintentar con backoff.
    case transient(pagesApplied: Int)
}

/// Error del seam de test `_testThrowOnApplySave` (simula un crash antes del commit de una página).
private enum ApplyTestCrash: Error { case suppressed }

// MARK: - Guard de pendientes (D-1)

/// Estado LWW derivado del `SyncOutbox` VIVO de UN `syncID`: el MAX HLC de sus upserts pendientes
/// (guard de tombstone) y el MAX HLC por-unidad (guard por-unidad del upsert).
private struct PendingGuard {
    var maxUpsertHLC: HLC?
    var unitHLCs: [String: HLC] = [:]
}

// MARK: - SyncApplyEngine

extension CloudSyncEngine {

    /// Orquestador D-2/F-1: drena, pullea y aplica página a página avanzando el cursor DURABLEMENTE por
    /// página (interrumpir a mitad = re-pull idempotente, D-2b). El drain se repite SÍNCRONO antes de
    /// CADA `applyPage` (F-1: cubre las ediciones que aterrizan durante la suspensión del `await pull`).
    /// Al final (haya terminado como haya terminado, salvo `.busy`) corre el pase de re-resolución de
    /// refs colgadas (F-2). `now` inyectable (determinismo del `receive` del reloj).
    /// - Parameters:
    ///   - client: transporte del pull (inyectable; stub en tests).
    ///   - pageLimit: tamaño de página (= `limit` del wire).
    ///   - maxPages: tope defensivo de páginas por ciclo (evita loops si el server nunca "agota").
    func pullAndApplyOnce(
        using client: SyncPullClient,
        context: ModelContext,
        now: Date = .now,
        pageLimit: Int = 500,
        maxPages: Int = 50
    ) async -> PullApplyOutcome {
        // D-2: nunca aplicar con un drain en curso. Defensivo (F-10): `drainOnce` es síncrono bajo
        // MainActor → esta rama es inalcanzable hoy; queda como red si el drain gana suspensión.
        guard !isDrainInProgress else { return .busy }
        // Drenar al entrar: captura las escrituras locales pendientes ANTES del primer fetch.
        drainOnce(context: context)

        let (outcome, pagesApplied) = await pullLoop(client: client, context: context, now: now,
                                                     pageLimit: pageLimit, maxPages: maxPages)
        // I8f-3 (guard A-3 del Merkle): registrar si este ciclo AGOTÓ la cola. Un ciclo incompleto
        // (transient/401/403) deja el flag en false → la verificación se salta (divergencia esperada).
        if case .completed = outcome {
            lastPullCycleCompleted = true
        } else {
            lastPullCycleCompleted = false
        }
        // F-2: pase de re-resolución de refs colgadas — corre SIEMPRE al final del ciclo (también en
        // salidas tempranas: lo aplicado hasta aquí es durable y puede haber destapado targets).
        reresolveDanglingRefs(context: context)
        // I8f-2 (D-D): reconciliadores cross-fila — SOLO si el ciclo aplicó ≥1 página (un ciclo vacío no
        // pudo introducir divergencia nueva), DESPUÉS de los danglers (una ref recién resuelta completa
        // la clasificación real-vs-virtual del split). Cada uno en su propio save con rollback-on-fail,
        // bajo autor NORMAL (sus writes DEBEN drenar/subir en el próximo ciclo).
        //
        // I9 (§G): gateados por QUIESCENCIA (`reconcilerQuiescenceGate`). `nil` = comportamiento actual
        // (corren siempre — tests intactos). Si el gate está PUESTO y CERRADO, se DIFIEREN
        // (`pendingReconcile = true`) para no saveear (autor NORMAL) sobre un grafo a medio importar
        // (anti-crash-loop de CLAUDE.md) → se reintentan al inicio de un ciclo futuro cuando el gate
        // abra, aunque ese ciclo aplique 0 páginas (no se pierde el repair).
        let gateOpen = reconcilerQuiescenceGate?() ?? true
        if pagesApplied > 0 {
            if gateOpen {
                runPostPullReconcilers(context: context)
                pendingReconcile = false
            } else {
                pendingReconcile = true
            }
        } else if pendingReconcile, gateOpen {
            // Reintento del repair diferido: el ciclo no aplicó páginas nuevas pero el gate ya abrió.
            runPostPullReconcilers(context: context)
            pendingReconcile = false
        }
        return outcome
    }

    /// El loop de páginas (separado para que los pases F-2/I8f-2 corran en TODAS las salidas). Devuelve
    /// también `pagesApplied` aparte del outcome (los cases `.sessionExpired`/`.accountUnavailable` no
    /// lo llevan, pero el gate de los reconcilers necesita saber si HUBO páginas antes de esa salida).
    private func pullLoop(
        client: SyncPullClient, context: ModelContext, now: Date, pageLimit: Int, maxPages: Int
    ) async -> (PullApplyOutcome, Int) {
        var pagesApplied = 0
        while pagesApplied < maxPages {
            let since: Int64
            do {
                since = try loadOrCreateCursor(context).serverSeqCursor
            } catch {
                #if DEBUG
                print("CloudSyncEngine.pullAndApplyOnce: loadCursor falló: \(error)")
                #endif
                return (.transient(pagesApplied: pagesApplied), pagesApplied)
            }

            let outcome = await client.pull(since: since, limit: pageLimit)
            switch outcome {
            case .page(let page):
                // Página vacía = cola agotada (nada nuevo desde `since`) → sin avanzar cursor.
                guard !page.deltas.isEmpty else {
                    return (.completed(pagesApplied: pagesApplied), pagesApplied)
                }
                // F-1: RE-drenar SÍNCRONO inmediatamente antes del apply — sin `await` entre medio.
                // Cubre toda edición local que aterrizó durante la suspensión del `await pull`: su fila
                // de outbox queda escrita y el guard D-1 protege sus unidades del full-row remoto.
                drainOnce(context: context)
                guard applyPage(page, context: context, now: now) else {
                    // F-3: el save de página falló (rollback ya hecho) → cortar; el cursor NO avanzó,
                    // así que reintentar el mismo `since` en este loop podría girar hasta maxPages.
                    return (.transient(pagesApplied: pagesApplied), pagesApplied)
                }
                pagesApplied += 1
                // Última página (menos deltas que el límite) → agotado.
                if page.deltas.count < pageLimit {
                    return (.completed(pagesApplied: pagesApplied), pagesApplied)
                }
                // Página llena → puede haber más: siguiente vuelta con el cursor ya avanzado.
            case .sessionExpired:
                return (.sessionExpired, pagesApplied)
            case .accountUnavailable:
                return (.accountUnavailable, pagesApplied)
            case .transient:
                return (.transient(pagesApplied: pagesApplied), pagesApplied)
            }
        }
        return (.completed(pagesApplied: pagesApplied), pagesApplied)  // tope defensivo alcanzado
    }

    // MARK: - Reconciliadores post-pull (I8f-2, D-D)

    /// Corre los 2 reconciliadores cross-fila, cada uno en su propio save con rollback-on-fail (patrón
    /// F-3), bajo autor NORMAL — el próximo drain captura sus writes (repair del money / tombstones de
    /// la poda) y los sube con HLC fresco. Un fallo de uno NO impide el otro. `internal` para tests.
    /// GATE I9 (cableado: `reconcilerQuiescenceGate` ← `SyncQuiescenceCoordinator.
    /// isQuiescentForEngineSaves`): en `.icloud` estos saves de autor NORMAL respetan la quiescencia
    /// del import de CloudKit AJENO (regla anti-crash-loop de CLAUDE.md); en `.cloud` la señal es
    /// `true` SIEMPRE — cuando esto corre, el save de página del PROPIO batch ya commiteó y no hay
    /// import ajeno. NO cablear `isImportQuiescent` aquí: queda `false` durante toda la ventana
    /// markApplyBegan/Ended que envuelve al pull (donde esto corre) → deferral perpetuo en `.cloud`
    /// (SERIO-1 del review de I9).
    func runPostPullReconcilers(context: ModelContext) {
        do {
            _ = CloudSyncReconciler.reconcileTransferPairDivergence(context: context)
            if context.hasChanges { try context.save() }  // autor NORMAL (debe drenar/subir)
        } catch {
            context.rollback()
            CloudSyncBreadcrumb.applyPageFailed(reason: "reconcilerTransfer:\(error)")
            #if DEBUG
            print("CloudSyncEngine.runPostPullReconcilers: transfer save falló: \(error)")
            #endif
        }
        do {
            _ = CloudSyncReconciler.reconcileSplitRepresentations(context: context)
            if context.hasChanges { try context.save() }  // autor NORMAL
        } catch {
            context.rollback()
            CloudSyncBreadcrumb.applyPageFailed(reason: "reconcilerSplit:\(error)")
            #if DEBUG
            print("CloudSyncEngine.runPostPullReconcilers: split save falló: \(error)")
            #endif
        }
        // Entidades de SISTEMA (política v1, residual gate de flags): GESTIONA SUS PROPIOS saves internos
        // bajo autor DEFAULT (el CSV-mirror exige el cascade `.nullify` committeado antes del re-encode) →
        // aquí solo se recoge el residual y se loguea un fallo del save final. Un fallo NO impide los otros.
        do {
            _ = CloudSyncReconciler.reconcileSystemEntities(context: context)
            if context.hasChanges { try context.save() }
        } catch {
            context.rollback()
            CloudSyncBreadcrumb.applyPageFailed(reason: "reconcilerSystem:\(error)")
            #if DEBUG
            print("CloudSyncEngine.runPostPullReconcilers: system save falló: \(error)")
            #endif
        }
    }

    /// Aplica UNA página en UN `saveWithAuthor` (D-5, atómico): por cada delta → apply|quarantine +
    /// `receive` del reloj; al final avanza `serverSeqCursor` y persiste el reloj (D-3). Devuelve `false`
    /// si el save falló — el contexto queda ROLLBACKEADO (F-3: sin rollback, el grafo remoto quedaría
    /// dirty y un autosave posterior lo flushearía bajo autor NO-motor → laundering) y el cursor NO
    /// avanza → el re-pull re-aplica idempotente.
    ///
    /// GUARDIA (F-8): SOLO llamable desde `pullAndApplyOnce` o tests — llamarla sin un `drainOnce`
    /// SÍNCRONO inmediatamente antes reintroduce el laundering de D-2 (una edición local sin drenar se
    /// machaca aquí y el próximo drain la relee del modelo vivo bajo un HLC fresco).
    @discardableResult
    func applyPage(_ page: PulledPage, context: ModelContext, now: Date) -> Bool {
        do {
            let cursor = try loadOrCreateCursor(context)
            loadClock(from: cursor)  // D-3: reloj desde el estado durable antes de integrar remotos

            let guards = buildPendingGuards(context)
            var quarantineSeqs = existingQuarantineSeqs(context)
            var newQuarantineCount = 0

            try saveWithAuthor(context, Self.outboxSaveAuthor) {
                for delta in page.deltas {
                    // D-3: integra el HLC de FILA de CADA delta (aplicado o cuarentenado) en el reloj.
                    if let remote = parseHLC(delta.hlc, site: "applyPage.rowHlc") {
                        receiveRemoteClock(remote, now: now)
                    }
                    if EntityApplyMap.isWired(table: delta.entityType) {
                        dispatchApply(delta, guard: guards[delta.syncID], context: context)
                    } else {
                        // §d.6/D-5: entity_type aún no materializable (10 de 16) → cuarentena (dedup seq).
                        if quarantineDelta(delta, existing: &quarantineSeqs, context: context) {
                            newQuarantineCount += 1
                        }
                    }
                }
                // D-5 + D-3: cursor + reloj en el MISMO save. `max` defensivo (nunca retroceder).
                cursor.serverSeqCursor = max(cursor.serverSeqCursor, page.maxServerSeq)
                cursor.clockLatestHLC = clockLatestString
                // I9 (§d.5 A1): testigo lockstep — se bumpea en el MISMO save que INSERTA las filas de
                // cuarentena (ÚNICO sitio de insert). Guard de recreación depende de esta atomicidad.
                if newQuarantineCount > 0 {
                    cursor.quarantinePendingCount += Int64(newQuarantineCount)
                }
                // Seam de test (D-5/F-3): crash antes del commit → rollback, cursor NO avanza.
                if _testThrowOnApplySave { throw ApplyTestCrash.suppressed }
            }
            return true
        } catch {
            // F-3: rollback OBLIGATORIO — el contexto tiene el grafo remoto a medias (born-remotes,
            // deletes, cursor mutado); dejarlo dirty = laundering vía el próximo autosave/save ajeno.
            context.rollback()
            CloudSyncBreadcrumb.applyPageFailed(reason: "\(error)")
            #if DEBUG
            print("CloudSyncEngine.applyPage: save falló (rollback; cursor NO avanza → re-pull idempotente): \(error)")
            #endif
            return false
        }
    }

    // MARK: - Dispatch concreto por tabla (nunca genérico por protocolo)

    private func dispatchApply(_ delta: PulledDelta, guard g: PendingGuard?, context: ModelContext) {
        switch delta.entityType {
        case EntityApplyMap.transactionItem.table:
            applyToEntity(delta, EntityApplyMap.transactionItem, guard: g, context: context)
        case EntityApplyMap.inboxDraft.table:
            applyToEntity(delta, EntityApplyMap.inboxDraft, guard: g, context: context)
        case EntityApplyMap.category.table:
            applyToEntity(delta, EntityApplyMap.category, guard: g, context: context)
        case EntityApplyMap.favoritePayment.table:
            applyToEntity(delta, EntityApplyMap.favoritePayment, guard: g, context: context)
        case EntityApplyMap.merchantMemory.table:
            applyToEntity(delta, EntityApplyMap.merchantMemory, guard: g, context: context)
        case EntityApplyMap.exchangeRate.table:
            applyToEntity(delta, EntityApplyMap.exchangeRate, guard: g, context: context)
        case EntityApplyMap.budget.table:
            applyToEntity(delta, EntityApplyMap.budget, guard: g, context: context)
        case EntityApplyMap.scheduledPayment.table:
            applyToEntity(delta, EntityApplyMap.scheduledPayment, guard: g, context: context)
        case EntityApplyMap.account.table:
            applyToEntity(delta, EntityApplyMap.account, guard: g, context: context)
        case EntityApplyMap.subcategory.table:
            applyToEntity(delta, EntityApplyMap.subcategory, guard: g, context: context)
        case EntityApplyMap.tag.table:
            applyToEntity(delta, EntityApplyMap.tag, guard: g, context: context)
        case EntityApplyMap.notificationItem.table:
            applyToEntity(delta, EntityApplyMap.notificationItem, guard: g, context: context)
        case EntityApplyMap.cashFlowPlan.table:
            applyToEntity(delta, EntityApplyMap.cashFlowPlan, guard: g, context: context)
        case EntityApplyMap.cashFlowLine.table:
            applyToEntity(delta, EntityApplyMap.cashFlowLine, guard: g, context: context)
        case EntityApplyMap.cashFlowOverride.table:
            applyToEntity(delta, EntityApplyMap.cashFlowOverride, guard: g, context: context)
        case EntityApplyMap.groupBridgePreference.table:
            applyToEntity(delta, EntityApplyMap.groupBridgePreference, guard: g, context: context)
        default:
            break  // isWired ya lo filtró; inalcanzable.
        }
    }

    /// Aplica un delta de una entidad CONCRETA `M` (upsert full-row con skip por-unidad, o tombstone).
    ///
    /// ASIMETRÍA CONSCIENTE (F-10): un upsert remoto sobre una fila con TOMBSTONE local pendiente la
    /// "resucita" localmente de forma TRANSITORIA — el server arbitra al pushear el tombstone (regla
    /// delete-vs-upsert de §d.4 cat.3) y el próximo pull converge. Parpadeo esperado; la reconciliación
    /// fina cross-fila es I8f-2.
    private func applyToEntity<M: PersistentModel>(
        _ delta: PulledDelta, _ entry: EntityApply<M>, guard g: PendingGuard?, context: ModelContext
    ) {
        switch delta.op {
        case .tombstone:
            // F-6d: un `deleted_hlc` malformado (nunca desde nuestro server) → NO borrar (skip; el
            // cursor avanza). Borrar es lo irreversible; el skip es lo conservador.
            guard let remote = parseHLC(delta.hlc, site: "tombstone.deletedHlc") else { return }
            // D-1/§d.4 cat.3: si un upsert local pendiente es MÁS NUEVO que el deleted_hlc, NO borramos
            // (el server reinstalará nuestra edición; convergencia por la regla delete-vs-upsert).
            if let g, let maxUp = g.maxUpsertHLC, maxUp > remote {
                return
            }
            // D-9: sin fila local → no-op (el cursor avanza igual). Con fila → borrar + matar la identidad.
            guard let model = entry.fetchBySyncID(delta.syncID, context) else { return }
            context.delete(model)
            if let identity = EntityApplyMap.fetchSyncIdentity(bySyncID: delta.syncID, context: context) {
                context.delete(identity)
            }
            // I8f-2 (D-A): higiene del clock por-unidad en el MISMO save de página (si el modelo
            // resucita por un upsert posterior, drain/apply lo re-pueblan).
            SyncUnitClockStore.delete(syncID: delta.syncID, context: context)

        case .upsert:
            // D-8: sin fila local → born-remote (crear + fijar syncID para que el sweep del drain no
            // re-acuñe otro). Con fila → materializar sobre ella.
            let model: M
            let isNew: Bool
            if let existing = entry.fetchBySyncID(delta.syncID, context) {
                model = existing
                isNew = false
            } else {
                model = entry.make(context)
                entry.setSyncID(model, delta.syncID)
                isNew = true
            }
            // Full-row (D-0): iterar SOLO las columnas presentes en `fields` (key ausente = no tocar).
            // F-4: en un BORN-REMOTE el skip por-unidad NO aplica — el guard D-1 protege ediciones
            // locales de una fila EXISTENTE; una fila outbox huérfana (upsert pendiente de un syncID
            // sin modelo) saltaría p.ej. el grupo money y dejaría el born-remote con los defaults del
            // init ($0, moneda equivocada) = fila incoherente. El full-row remoto se materializa ÍNTEGRO.
            // I8f-2 (D-A): las unidades APLICADAS (no las saltadas por D-1 — la saltada conserva el HLC
            // local pendiente que el drain ya escribió en el clock) alimentan el `SyncUnitClock` con el
            // HLC remoto de esa unidad, en el MISMO save de página.
            var appliedUnits: [String: String] = [:]
            for (column, value) in delta.fields {
                guard let applier = entry.appliers[column] else { continue }  // p.ej. local_day / no cableada
                let unit = entry.unit(for: column)
                if !isNew {
                    if shouldSkipUnit(unit, remoteFieldHlcs: delta.fieldHlcs, guard: g) { continue }  // D-1
                }
                applier.apply(model, value, context)
                if let remoteUnitHLC = delta.fieldHlcs[unit] {
                    appliedUnits[unit] = remoteUnitHLC
                }
            }
            if !appliedUnits.isEmpty {
                SyncUnitClockStore.upsert(syncID: delta.syncID, entityTable: delta.entityType,
                                          unitHlcs: appliedUnits, context: context)
            }
            if isNew {
                ensureIdentity(for: model, entry: entry, syncID: delta.syncID, context: context)
            }
        }
    }

    /// D-1 por-unidad: `true` si una fila de outbox VIVA de este `syncID` tiene la unidad `unit` con un
    /// HLC `>=` al remoto → la unidad remota se SALTA (la edición local más nueva ganará al pushear).
    /// Sin base local (unidad ausente en el guard) o sin HLC remoto parseable → NO se salta (aplica).
    private func shouldSkipUnit(
        _ unit: String, remoteFieldHlcs: [String: String], guard g: PendingGuard?
    ) -> Bool {
        guard let g, let localHLC = g.unitHLCs[unit] else { return false }
        guard let remoteStr = remoteFieldHlcs[unit],
              let remote = parseHLC(remoteStr, site: "shouldSkipUnit.fieldHlc") else { return false }
        return localHLC >= remote
    }

    /// D-8: materializa la fila testigo `SyncIdentity` del born-remote (ancla del contenido YA aplicado)
    /// si no existe — para que backfill/rebind (I10) no dupliquen. Idempotente.
    private func ensureIdentity<M: PersistentModel>(
        for model: M, entry: EntityApply<M>, syncID: UUID, context: ModelContext
    ) {
        guard EntityApplyMap.fetchSyncIdentity(bySyncID: syncID, context: context) == nil else { return }
        let row = SyncIdentity(
            syncID: syncID,
            entityType: entry.entityTypeName,
            localAnchor: entry.anchor(model)
        )
        context.insert(row)
    }

    // MARK: - Re-resolución de refs colgadas (F-2)

    /// Pase final de `pullAndApplyOnce`: intenta re-resolver cada `SyncDanglingRef` (el destino pudo
    /// llegar en una página posterior del MISMO ciclo). Resuelto o fila-origen-borrada → borra el
    /// dangler; target aún ausente → lo conserva (reintento en el próximo ciclo). Save propio bajo
    /// `outboxSaveAuthor` (el drain NO re-captura estos sets — echo-suppression D-4).
    func reresolveDanglingRefs(context: ModelContext) {
        let danglers: [SyncDanglingRef]
        do {
            danglers = try context.fetch(FetchDescriptor<SyncDanglingRef>())
        } catch {
            #if DEBUG
            print("CloudSyncEngine.reresolveDanglingRefs: fetch falló: \(error)")
            #endif
            return
        }
        guard !danglers.isEmpty else { return }
        do {
            try saveWithAuthor(context, Self.outboxSaveAuthor) {
                for dangler in danglers {
                    switch EntityApplyMap.reresolveDangler(dangler, context: context) {
                    case .resolved, .rowGone:
                        context.delete(dangler)
                    case .targetMissing:
                        break  // se conserva; reintento en el próximo ciclo
                    }
                }
            }
        } catch {
            // Sin rollback aquí: los sets de relaciones son idempotentes y el próximo ciclo re-intenta;
            // pero no dejamos el contexto dirty en silencio.
            context.rollback()
            CloudSyncBreadcrumb.applyPageFailed(reason: "reresolve:\(error)")
            #if DEBUG
            print("CloudSyncEngine.reresolveDanglingRefs: save falló: \(error)")
            #endif
        }
    }

    // MARK: - Cuarentena (D-5/D-6)

    /// Inserta el delta en cuarentena. Devuelve `true` si INSERTÓ una fila nueva (para el bump lockstep
    /// del testigo `quarantinePendingCount`), `false` si el `serverSeq` ya estaba (dedup idempotente).
    @discardableResult
    private func quarantineDelta(
        _ delta: PulledDelta, existing: inout Set<Int64>, context: ModelContext
    ) -> Bool {
        guard !existing.contains(delta.serverSeq) else { return false }  // dedup por serverSeq (re-pull idempotente)
        context.insert(SyncQuarantine(
            serverSeq: delta.serverSeq,
            entityType: delta.entityType,
            syncID: delta.syncID,
            rawDelta: delta.rawDelta,
            hlc: delta.hlc
        ))
        existing.insert(delta.serverSeq)
        CloudSyncBreadcrumb.applyQuarantined(entity: delta.entityType, serverSeq: delta.serverSeq)
        return true
    }

    private func existingQuarantineSeqs(_ context: ModelContext) -> Set<Int64> {
        do {
            return Set(try context.fetch(FetchDescriptor<SyncQuarantine>()).map(\.serverSeq))
        } catch {
            #if DEBUG
            print("CloudSyncEngine.existingQuarantineSeqs: fetch falló: \(error)")
            #endif
            return []
        }
    }

    // MARK: - Drenaje de cuarentena (upgrade path, I9 §F)

    /// Re-aplica las filas de `SyncQuarantine` cuya `entityType` YA está cableada al apply (típicamente
    /// tras un update de app que cablea una entidad antes no materializable). HOY es SIEMPRE no-op en
    /// prod: las 6 tablas cableadas nunca se cuarentenan → la cuarentena solo guarda las 10 no cableadas;
    /// el mecanismo queda listo para cuando un update cablee más.
    ///
    /// GUARDIA (F-8, misma disciplina anti-laundering que `applyPage`): SOLO llamable desde `start()`
    /// del runtime (o tests) tras `rehydrateOutboxFromMirror` **y** un `drainOnce` SÍNCRONO inmediatamente
    /// antes (sin `await` entre medio) — sin ese drain, una edición local sin capturar se machacaría al
    /// re-aplicar el delta cuarentenado y el próximo drain la relee bajo un HLC fresco (laundering D-2).
    ///
    /// Contrato: re-decodifica `rawDelta` con EL MISMO decoder del pull (`SyncPullClient.decodeDelta`),
    /// orden `serverSeq` ASC, integra el HLC de fila en el reloj (D-3), aplica con el guard D-1
    /// (`buildPendingGuards`), borra las filas consumidas y DECREMENTA el testigo lockstep — todo en UN
    /// `saveWithAuthor(outboxSaveAuthor)`. **NO toca `serverSeqCursor`** (esos `server_seq` ya pasaron —
    /// avanzarlo re-saltaría deltas). Falla el save → rollback + las filas siguen (reintento al próximo
    /// arranque). Después: `reresolveDanglingRefs` (los deltas re-aplicados pueden colgar refs).
    func drainQuarantineOnce(context: ModelContext, now: Date = .now) {
        let rows: [SyncQuarantine]
        do {
            rows = try context.fetch(FetchDescriptor<SyncQuarantine>(
                sortBy: [SortDescriptor(\.serverSeq, order: .forward)]
            ))
        } catch {
            #if DEBUG
            print("CloudSyncEngine.drainQuarantineOnce: fetch falló: \(error)")
            #endif
            return
        }
        let drainable = rows.filter { EntityApplyMap.isWired(table: $0.entityType) }
        guard !drainable.isEmpty else { return }  // hoy SIEMPRE vacío en prod (las 6 cableadas no se cuarentenan)

        let cursor: SyncCursor
        do {
            cursor = try loadOrCreateCursor(context)
            loadClock(from: cursor)  // D-3: reloj desde el estado durable antes de integrar remotos
        } catch {
            #if DEBUG
            print("CloudSyncEngine.drainQuarantineOnce: loadCursor falló: \(error)")
            #endif
            return
        }
        let guards = buildPendingGuards(context)
        var consumed = 0
        do {
            try saveWithAuthor(context, Self.outboxSaveAuthor) {
                for row in drainable {
                    let delta: PulledDelta
                    do {
                        delta = try SyncPullClient.decodeDelta(row.rawDelta)
                    } catch {
                        // `rawDelta` corrupto (no debe ocurrir — lo serializó el propio pull) → dejar la
                        // fila cuarentenada (no se puede re-aplicar) sin romper el batch.
                        #if DEBUG
                        print("CloudSyncEngine.drainQuarantineOnce: rawDelta no decodifica (\(row.entityType)): \(error)")
                        #endif
                        continue
                    }
                    // D-3: integra el HLC de fila en el reloj.
                    if let remote = parseHLC(delta.hlc, site: "drainQuarantine.rowHlc") {
                        receiveRemoteClock(remote, now: now)
                    }
                    dispatchApply(delta, guard: guards[delta.syncID], context: context)
                    context.delete(row)
                    consumed += 1
                }
                // D-3: persistir el reloj. NO tocar `serverSeqCursor` (esos server_seq ya pasaron).
                cursor.clockLatestHLC = clockLatestString
                // Testigo lockstep: decrementar por las filas consumidas en el MISMO save que las borra
                // (floor 0 defensivo por si el testigo divergiera del conteo real).
                if consumed > 0 {
                    cursor.quarantinePendingCount = max(0, cursor.quarantinePendingCount - Int64(consumed))
                }
            }
        } catch {
            context.rollback()
            CloudSyncBreadcrumb.applyPageFailed(reason: "drainQuarantine:\(error)")
            #if DEBUG
            print("CloudSyncEngine.drainQuarantineOnce: save falló (rollback; filas siguen → reintento): \(error)")
            #endif
            return
        }
        if consumed > 0 {
            CloudSyncBreadcrumb.quarantineDrained(count: consumed)
            // Los deltas re-aplicados pueden colgar refs → re-resolver (save propio bajo outboxSaveAuthor).
            reresolveDanglingRefs(context: context)
        }
    }

    // MARK: - Reconcilers de arranque (I9 §E AJUSTE review)

    /// Corre `runPostPullReconcilers` UNA vez en el arranque del runtime si el gate de quiescencia está
    /// abierto — cierra el hueco del `pendingReconcile` EN MEMORIA perdido por un kill (los reconcilers
    /// son idempotentes). Si el gate está cerrado, arma `pendingReconcile` para el reintento del primer
    /// ciclo. Usa el `reconcilerQuiescenceGate` ya instalado por el runtime (nil → corre).
    func runStartupReconcilersIfQuiescent(context: ModelContext) {
        if reconcilerQuiescenceGate?() ?? true {
            runPostPullReconcilers(context: context)
            pendingReconcile = false
        } else {
            pendingReconcile = true
        }
    }

    // MARK: - Guard de pendientes (D-1)

    /// Construye el guard LWW por `syncID` desde el `SyncOutbox` VIVO (`rejectedReason == nil`). Un
    /// dead-letter NUNCA llega al server → contarlo bloquearía la unidad remota para siempre (D-1
    /// exclusión). Solo los UPSERT pendientes cuentan para `maxUpsertHLC` (el árbitro de tombstone) y
    /// para las unidades (`fieldHlcsJSON`).
    private func buildPendingGuards(_ context: ModelContext) -> [UUID: PendingGuard] {
        var result: [UUID: PendingGuard] = [:]
        do {
            for row in try context.fetch(FetchDescriptor<SyncOutbox>()) {
                guard row.rejectedReason == nil else { continue }  // dead-letter excluido
                guard SyncOutboxOp(rawValue: row.opRaw) == .upsert else { continue }
                var g = result[row.syncID] ?? PendingGuard()
                if let rowHLC = parseHLC(row.hlc, site: "pendingGuard.rowHlc") {
                    if g.maxUpsertHLC == nil || rowHLC > g.maxUpsertHLC! { g.maxUpsertHLC = rowHLC }
                }
                if let json = row.fieldHlcsJSON, let map = Self.decodeFieldHlcs(json) {
                    for (unit, hlcStr) in map {
                        guard let uh = parseHLC(hlcStr, site: "pendingGuard.fieldHlc") else { continue }
                        if let cur = g.unitHLCs[unit] {
                            if uh > cur { g.unitHLCs[unit] = uh }
                        } else {
                            g.unitHLCs[unit] = uh
                        }
                    }
                }
                result[row.syncID] = g
            }
        } catch {
            #if DEBUG
            print("CloudSyncEngine.buildPendingGuards: fetch falló: \(error)")
            #endif
        }
        return result
    }

    /// F-6c: parse de un HLC con rastro (cero silencios). Un HLC malformado en el pipeline del apply
    /// (wire u outbox) no debe ocurrir desde nuestro server/drain → breadcrumb con el SITE (sin PII) y
    /// `nil` para que el caller tome la rama CONSERVADORA (aplicar la unidad / no borrar).
    private func parseHLC(_ raw: String, site: String) -> HLC? {
        do {
            return try HLC.parse(raw)
        } catch {
            CloudSyncBreadcrumb.hlcUnparseable(site: site)
            #if DEBUG
            print("CloudSyncEngine.parseHLC[\(site)]: '\(raw)' no parsea: \(error)")
            #endif
            return nil
        }
    }

    /// Parsea el `fieldHlcsJSON` (`{unit:hlc}`) del outbox. `nil` si no decodifica (fila corrupta → sin
    /// guard por-unidad para esa fila; conservador: el peor caso es aplicar un remoto que se re-pushea).
    /// F-6a: con rastro — un JSON corrupto desactiva el guard de esa fila y debe verse en DEBUG.
    private static func decodeFieldHlcs(_ json: String) -> [String: String]? {
        let data = Data(json.utf8)
        do {
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            #if DEBUG
            print("CloudSyncEngine.decodeFieldHlcs: fieldHlcsJSON corrupto (guard por-unidad desactivado para esa fila): \(error)")
            #endif
            return nil
        }
    }
}

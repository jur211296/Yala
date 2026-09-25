//
//  SyncMerkle.swift
//  Yala
//
//  Verificación de integridad Merkle del Canal 1 (Modo Nube, incremento I8f-3, §d.7). El cliente
//  computa su árbol LOCAL (las 6 entidades cableadas, proyección FULL vía `EntityEmissionMap` →
//  `Canonc1Codec`) y lo compara contra el snapshot del backend (`/sync/merkle`, buckets POR ENTIDAD —
//  regla A-1: detección exacta a nivel tabla; la remediación v1 = re-pull completo y el trie fino
//  queda diferido).
//
//  REGLA DE ENSAMBLADO A-4 (CONGELADA, cross-lenguaje — fijada por `merkle_fixtures.json`):
//    leaf   = sha256( utf8(sync_id_lowercase_36) ‖ sha256(utf8(payload_c1)) )   (Canal 1, SIN hlc)
//    entity = sha256( concat( leaves ordenados por sync_id bytes UTF-8 asc ) ); vacía → sha256("")
//    root   = sha256( concat( entityHash de las 16 tablas en orden UTF-8 asc de nombre ) )
//  Los digests se concatenan CRUDOS (32 bytes), nunca su hex.
//
//  EXCLUSIONES simétricas (una asimetría = divergencia FALSA PERMANENTE del canario):
//   - Filas `deleted=true` FUERA del Canal 1 (A-2): el cliente no tiene fila local que hashear para un
//     tombstone aplicado. (El Canal 2 del Worker sí las incluye — el cliente NO lo recomputa.)
//   - **`local_day` FUERA del leaf en AMBOS lados (A-2b)**: el cliente NO la almacena (derivada de
//     `date`; el apply la ignora) → re-derivarla con el calendario ACTUAL diverge de la ALMACENADA
//     ante cualquier cambio de huso. Sigue siendo columna del PULL y del dedup S9; solo sale de la
//     auditoría Merkle. Consecuencia feliz: el hash local es independiente del calendario del device.
//
//  LÍMITE HONESTO v1 (regla 5 del plan): el cliente declara capability-set v1 (16 tablas) pero solo
//  MATERIALIZA 6 — una fila server-side de una tabla no cableada (cuarentenada localmente) haría
//  diverger su entityHash sin que sea incidente. Por eso `verifyIntegrity` compara SOLO los entityHash
//  de las 6 cableadas, SALTA las tablas con cuarentena local, y el root global se compara SOLO sin
//  cuarentena. Desaparece al cablear las 16.
//

import CryptoKit
import Foundation
import SwiftData

// MARK: - SyncMerkle (cómputo local + ensamblado puro)

/// Una lectura de la base LOCAL que no se pudo hacer durante el cómputo del árbol (ticket
/// `verify-reads-a-failed-local-fetch-as-an-empty-outbox`). Existe para que el fallo tenga un TIPO y no se
/// confunda con el error de canonicalización de una fila, que es otra cosa y se salta: aquí no hay corpus que
/// comparar, y comparar un corpus que no se leyó produce una divergencia que no ocurrió.
enum SyncMerkleLocalReadError: Error, Equatable {
    /// El fetch de las filas de una entidad cableada lanzó. `entity` es el nombre de tabla (sin PII).
    case leafFetchFailed(entity: String)
    /// El fetch del registro de refs colgadas lanzó. Sin él los leaves emiten `null` donde el servidor tiene el
    /// UUID: no es un detalle, es divergencia falsa garantizada en multi-device.
    case danglingFetchFailed
}

@MainActor
enum SyncMerkle {

    /// Columnas emitidas que NO entran al leaf del Canal 1 (A-2b). Simétrico con `canon.ts`.
    nonisolated static let channel1ExcludedColumns: Set<String> = ["local_day"]

    /// Seams para montar «la base local no se deja leer» sin tocar el store: `ModelContext` es una `final class`
    /// de SwiftData sin protocolo detrás, así que no hay doble que inyectar. Molde de
    /// `CloudSyncEngine._testThrowOnTokenHistoryFetch` y sus tres hermanos. SOLO tests.
    ///
    /// **Son DOS y no uno, y esa es la diferencia entre medir y creer que se mide.** `computeLocalMerkle` llama a
    /// `danglingOverrides` ANTES que a cualquier `collectLeaves`, así que con un solo `Bool` el primero corta
    /// siempre y **el `catch` del segundo es inalcanzable**: un mutante que le devolviera `return []` pasaría en
    /// verde. Es el mismo argumento que obligó a que el seam del outbox de `MigrationWorkExecutor` sea un
    /// contador y no un `Bool`; aquí se olvidó, y lo cazó una lente de la review del 2026-09-22.
    static var _testThrowOnDanglingFetch = false
    static var _testThrowOnLeafFetch = false

    struct EntitySummary: Equatable {
        let count: Int
        let hashHex: String
    }

    struct LocalMerkle: Equatable {
        /// tabla → (count, entityHash hex). Las 16 tablas SIEMPRE (las 10 no cableadas = hash-vacío).
        let entities: [String: EntitySummary]
        let rootHex: String
    }

    // MARK: Cómputo local

    /// Computa el árbol local del Canal 1: para las 6 entidades cableadas, filas con `syncID != nil` →
    /// proyección FULL (todas las columnas emitidas MENOS `local_day`) → canon c1 → leaf → entityHash.
    /// Las 10 tablas restantes aportan su hash-vacío (el cliente no las materializa — límite v1).
    ///
    /// **`throws` desde el 2026-09-22** (ticket `verify-reads-a-failed-local-fetch-as-an-empty-outbox`): una
    /// lectura local que falla ya no se ensambla como un corpus vacío. El único consumidor de producción es
    /// `verifyIntegrity`, que lo convierte en `.skipped(localMerkleFetchFailed)`.
    static func computeLocalMerkle(context: ModelContext) throws -> LocalMerkle {
        var digests: [String: Data] = [:]
        var entities: [String: EntitySummary] = [:]

        // Las 16 tablas del manifest parten como vacías (hash de "").
        for table in EntityEmissionMap.catalog.keys {
            digests[table] = emptyDigest
            entities[table] = EntitySummary(count: 0, hashHex: hexString(emptyDigest))
        }

        let overrides = try danglingOverrides(context: context)

        // Las cableadas se computan de verdad (dispatch CONCRETO por tipo). D1: la identidad de sync es
        // `syncID` (las 6 sintéticas) o `id` (las cableadas en I12) — se pasa como closure.
        let computed: [(String, [(String, Data)])] = try [
            (EntityEmissionMap.transactionItem.table,
             collectLeaves(TransactionItem.self, emission: EntityEmissionMap.transactionItem,
                           identity: { $0.syncID }, overrides: overrides, context: context)),
            (EntityEmissionMap.inboxDraft.table,
             collectLeaves(InboxDraft.self, emission: EntityEmissionMap.inboxDraft,
                           identity: { $0.syncID }, overrides: overrides, context: context)),
            (EntityEmissionMap.category.table,
             collectLeaves(Category.self, emission: EntityEmissionMap.category,
                           identity: { $0.syncID }, overrides: overrides, context: context)),
            (EntityEmissionMap.favoritePayment.table,
             collectLeaves(FavoritePayment.self, emission: EntityEmissionMap.favoritePayment,
                           identity: { $0.syncID }, overrides: overrides, context: context)),
            (EntityEmissionMap.merchantMemory.table,
             collectLeaves(MerchantMemory.self, emission: EntityEmissionMap.merchantMemory,
                           identity: { $0.syncID }, overrides: overrides, context: context)),
            (EntityEmissionMap.exchangeRate.table,
             collectLeaves(ExchangeRate.self, emission: EntityEmissionMap.exchangeRate,
                           identity: { $0.syncID }, overrides: overrides, context: context)),
            (EntityEmissionMap.budget.table,
             collectLeaves(Budget.self, emission: EntityEmissionMap.budget,
                           identity: { $0.id }, overrides: overrides, context: context)),
            (EntityEmissionMap.scheduledPayment.table,
             collectLeaves(ScheduledPayment.self, emission: EntityEmissionMap.scheduledPayment,
                           identity: { $0.id }, overrides: overrides, context: context)),
            // I12 commit B: las 8 restantes. Identidad = `shortcutID` (Account/Subcategory) o `id` (resto).
            (EntityEmissionMap.account.table,
             collectLeaves(Account.self, emission: EntityEmissionMap.account,
                           identity: { $0.shortcutID }, overrides: overrides, context: context)),
            (EntityEmissionMap.subcategory.table,
             collectLeaves(Subcategory.self, emission: EntityEmissionMap.subcategory,
                           identity: { $0.shortcutID }, overrides: overrides, context: context)),
            (EntityEmissionMap.tag.table,
             collectLeaves(Tag.self, emission: EntityEmissionMap.tag,
                           identity: { $0.id }, overrides: overrides, context: context)),
            (EntityEmissionMap.notificationItem.table,
             collectLeaves(NotificationItem.self, emission: EntityEmissionMap.notificationItem,
                           identity: { $0.id }, overrides: overrides, context: context)),
            (EntityEmissionMap.cashFlowPlan.table,
             collectLeaves(CashFlowPlan.self, emission: EntityEmissionMap.cashFlowPlan,
                           identity: { $0.id }, overrides: overrides, context: context)),
            (EntityEmissionMap.cashFlowLine.table,
             collectLeaves(CashFlowLine.self, emission: EntityEmissionMap.cashFlowLine,
                           identity: { $0.id }, overrides: overrides, context: context)),
            (EntityEmissionMap.cashFlowOverride.table,
             collectLeaves(CashFlowOverride.self, emission: EntityEmissionMap.cashFlowOverride,
                           identity: { $0.id }, overrides: overrides, context: context)),
            (EntityEmissionMap.groupBridgePreference.table,
             collectLeaves(GroupBridgePreference.self, emission: EntityEmissionMap.groupBridgePreference,
                           identity: { $0.id }, overrides: overrides, context: context)),
        ]
        for (table, leaves) in computed {
            let digest = entityDigest(leaves)
            digests[table] = digest
            entities[table] = EntitySummary(count: leaves.count, hashHex: hexString(digest))
        }

        return LocalMerkle(entities: entities, rootHex: hexString(rootDigest(entityDigests: digests)))
    }

    /// Overrides de refs COLGADAS por fila (`rowSyncID → {columna: targetUUID}`), desde el registro
    /// durable `SyncDanglingRef` (I8f-1/F-2). **LOAD-BEARING para el Merkle en v1**: los `_ref`
    /// singulares apuntan a entidades que NO viajan en v1 (Account/Subcategory por `shortcutID`,
    /// Category de otro device aún no llegada) → en un segundo device la relación local es `nil`
    /// PERO el server almacena el UUID. Sin este override, el leaf emitiría `null` donde el server
    /// tiene el uuid → divergencia FALSA PERMANENTE por diseño en CUALQUIER multi-device. El dangler
    /// ES el conocimiento local del wire — usarlo en el leaf responde la pregunta correcta del Canal 1:
    /// "¿sé todo lo que el server sabe?" (sí, aunque no pueda materializar la relación todavía).
    ///
    /// **LANZA si su fetch lanza, y por lo que dice el párrafo de arriba** (ticket
    /// `verify-reads-a-failed-local-fetch-as-an-empty-outbox`). Hasta el 2026-09-22 se tragaba el error y seguía
    /// con el diccionario a medias, que es EXACTAMENTE el escenario que este registro existe para evitar: sin los
    /// overrides los `_ref` singulares emiten `null` donde el servidor tiene el UUID ⇒ divergencia falsa en
    /// cualquier multi-device. Un override ausente por avería no se distingue de un override que no existe, así
    /// que el único desenlace honesto es no comparar.
    private static func danglingOverrides(context: ModelContext) throws -> [UUID: [String: UUID]] {
        var overrides: [UUID: [String: UUID]] = [:]
        // El seam va DENTRO del `do`, no antes: así el camino de error que recorre un test es el `catch` REAL
        // del fetch. Puesto fuera, un mutante que reintrodujera `return []` ahí seguiría verde.
        do {
            if _testThrowOnDanglingFetch { throw SyncMerkleLocalReadError.danglingFetchFailed }
            for dangler in try context.fetch(FetchDescriptor<SyncDanglingRef>()) {
                overrides[dangler.rowSyncID, default: [:]][dangler.column] = dangler.targetUUID
            }
        } catch {
            #if DEBUG
            print("SyncMerkle.danglingOverrides fetch falló: \(error)")
            #endif
            CloudSyncBreadcrumb.merkleLocalReadFailed(stage: "dangling-overrides")
            throw SyncMerkleLocalReadError.danglingFetchFailed
        }
        return overrides
    }

    /// Leaves de UNA entidad cableada. Una fila cuyo payload el codec rechaza (dato no-canonicalizable;
    /// tampoco habría podido pushearse — el drain la descarta con canario) se SALTA con rastro: mejor
    /// una divergencia detectable que un crash del verificador (hueco documentado v1).
    ///
    /// **El fetch que lanza NO se salta: LANZA** (ticket `verify-reads-a-failed-local-fetch-as-an-empty-outbox`).
    /// Hasta el 2026-09-22 devolvía `[]`, y `[]` no es «esta tabla está vacía»: el ensamblado lo hashea con
    /// `sha256("")` —el hash del corpus vacío, byte a byte el mismo— así que una tabla ILEGIBLE y una tabla SIN
    /// FILAS producían el mismo entityHash. Con el servidor poblado eso sale de `verifyIntegrity` como
    /// `.diverged`, o sea como una pérdida de integridad que no ocurrió; y en la vuelta a iCloud una divergencia
    /// consume presupuesto de MISMATCH, que termina en `reverseFailedRollback`. Las dos filas del contraste viven
    /// en esta misma función: la fila que no canonicaliza deja rastro (`encodeRejected`) y se salta, porque el
    /// resto de la tabla SÍ se leyó; la tabla que no se pudo leer no deja nada que comparar.
    ///
    /// La distinción entre las dos es lo que separa «sé lo que hay y una fila no cabe» de «no sé lo que hay».
    private static func collectLeaves<M: PersistentModel>(
        _ type: M.Type, emission: EntityEmission<M>, identity: (M) -> UUID?,
        overrides: [UUID: [String: UUID]], context: ModelContext
    ) throws -> [(String, Data)] {
        let models: [M]
        // El seam va DENTRO del `do`, no antes: así el camino de error que recorre un test es el `catch` REAL
        // del fetch. Puesto fuera, un mutante que reintrodujera `return []` ahí seguiría verde.
        do {
            if _testThrowOnLeafFetch { throw SyncMerkleLocalReadError.leafFetchFailed(entity: emission.table) }
            models = try context.fetch(FetchDescriptor<M>())
        } catch {
            #if DEBUG
            print("SyncMerkle.collectLeaves<\(M.self)> fetch falló: \(error)")
            #endif
            CloudSyncBreadcrumb.merkleLocalReadFailed(stage: "leaves:\(emission.table)")
            throw SyncMerkleLocalReadError.leafFetchFailed(entity: emission.table)
        }
        var leaves: [(String, Data)] = []
        for model in models {
            guard let syncID = identity(model) else { continue }  // sin identidad → aún no participa
            do {
                let payload = try channel1Payload(model: model, emission: emission,
                                                  overrides: overrides[syncID] ?? [:])
                let sid = syncID.uuidString.lowercased()
                leaves.append((sid, leafDigest(syncID: sid, payload: payload)))
            } catch {
                #if DEBUG
                print("SyncMerkle: payload de \(emission.table) no canonicalizable (fila saltada): \(error)")
                #endif
                CloudSyncBreadcrumb.encodeRejected(entity: emission.table, reason: "merkle:\(error)")
            }
        }
        return leaves
    }

    /// Payload canónico c1 del leaf: proyección FULL de la fila (todas las columnas emitidas MENOS
    /// `local_day`, A-2b) + override de refs COLGADAS (`overrides`: columna → targetUUID del wire — solo
    /// pisa valores emitidos como `null`; si la relación ya resolvió, el valor real manda y el dangler
    /// estaría obsoleto). El calendario pasado a los builders es IRRELEVANTE (solo `local_day` lo usa y
    /// está excluida) → el hash es independiente del huso del device. `internal` para tests.
    static func channel1Payload<M>(
        model: M, emission: EntityEmission<M>, overrides: [String: UUID] = [:]
    ) throws -> String {
        var fields: [String: CanonValue] = [:]
        let calendar = Calendar(identifier: .gregorian)
        for emitter in emission.emitters where !channel1ExcludedColumns.contains(emitter.column) {
            var value = emitter.build(model, calendar)
            if case .null = value, let target = overrides[emitter.column] {
                value = .uuid(target)  // conocimiento del wire preservado por SyncDanglingRef
            }
            fields[emitter.column] = value
        }
        return try Canonc1Codec.encode(fields, groupedColumns: Set(emission.groupByColumn.keys))
    }

    // MARK: Ensamblado A-4 (puro; fijado por merkle_fixtures.json)

    /// sha256 de la cadena vacía (entidad sin filas).
    nonisolated static var emptyDigest: Data { Data(SHA256.hash(data: Data())) }

    /// leaf = sha256(utf8(sync_id) ‖ sha256(utf8(payload))). `syncID` DEBE venir lowercase-36.
    nonisolated static func leafDigest(syncID: String, payload: String) -> Data {
        var input = Data(syncID.utf8)
        input.append(Data(SHA256.hash(data: Data(payload.utf8))))
        return Data(SHA256.hash(data: input))
    }

    /// entityHash = sha256(concat(leaves ordenados por sync_id bytes UTF-8 asc)).
    nonisolated static func entityDigest(_ leaves: [(String, Data)]) -> Data {
        let sorted = leaves.sorted { Canonc1Codec.utf8BytesLess($0.0, $1.0) }
        var concat = Data()
        for (_, leaf) in sorted { concat.append(leaf) }
        return Data(SHA256.hash(data: concat))
    }

    /// root = sha256(concat(entityHash en orden UTF-8 asc del nombre de tabla)).
    nonisolated static func rootDigest(entityDigests: [String: Data]) -> Data {
        let ordered = entityDigests.keys.sorted(by: Canonc1Codec.utf8BytesLess)
        var concat = Data()
        for table in ordered {
            guard let digest = entityDigests[table] else { continue }
            concat.append(digest)
        }
        return Data(SHA256.hash(data: concat))
    }

    nonisolated static func hexString(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - MerkleVerdict + verifyIntegrity

/// Los `reason` de `.skipped` que produce `verifyIntegrity`, en UN solo sitio.
///
/// **Existen porque el literal es una junta entre dos ficheros, y desde el 2026-09-22 esa junta decide cosas
/// distintas a cada lado** (`reverse-verify-network-bucket-hides-a-definitive-server-no`): `VerifyProbeMapping` manda
/// `outbox-fetch-failed` al techo CORTO con un copy y el `default` a otro, así que una errata en el literal de aquí
/// —o un renombrado en uno solo de los dos lados— cambiaría el desenlace en producción **sin poner ni un test en
/// rojo**: el test del mapping construye su veredicto con el mismo literal que consume, así que se mide contra sí
/// mismo. Lo cazó una lente de la review. Antes de ese día la errata era inocua, porque los dos caían en «red».
///
/// Los de Grupos (`GroupsSyncClient.verifyGroupIntegrity`) NO están aquí: son de otro canal, no pasan por este
/// mapping y comparten solo el tipo del veredicto.
nonisolated enum MerkleSkipReason {
    static let outboxPending = "outbox-pending"
    static let deadLetters = "dead-letters"
    static let noCompletedPull = "no-completed-pull"
    static let fetchFailed = "fetch-failed"
    static let outboxFetchFailed = "outbox-fetch-failed"
    static let quarantineFetchFailed = "quarantine-fetch-failed"
    /// El cómputo del árbol LOCAL no pudo leer el corpus (ticket
    /// `verify-reads-a-failed-local-fetch-as-an-empty-outbox`). **Motivo PROPIO y no un reuso de
    /// `outboxFetchFailed`**: el desenlace de los dos es el mismo —`.blocked(.localFailure)`— pero el `rawValue`
    /// es lo único que deja distinguir en la flota «no pude leer la cola de subida» de «no pude leer los datos»,
    /// y son averías distintas con remedios distintos. Juntarlos ahorraba una constante y borraba esa señal.
    static let localMerkleFetchFailed = "local-merkle-fetch-failed"
    static let canonVersionMismatch = "canon-version-mismatch"
    static let capabilitySetMismatch = "capability-set-mismatch"

    /// Los NUEVE, para que el mapping y su canario de motivo desconocido no tengan que repetirlos.
    static let all: [String] = [
        outboxPending, deadLetters, noCompletedPull, fetchFailed,
        outboxFetchFailed, quarantineFetchFailed, localMerkleFetchFailed,
        canonVersionMismatch, capabilitySetMismatch,
    ]
}

/// Veredicto de una verificación de integridad. La REMEDIACIÓN (re-pull reconciliado de la tabla
/// divergente) NO se dispara automática en I8f-3 — es wiring de I9; el verdict la habilita.
enum MerkleVerdict: Equatable {
    case converged
    /// Tablas cuyo entityHash local ≠ remoto (o `"root"` si solo divergió el root global).
    case diverged(entities: [String])
    /// No se verificó (precondición A-3 no satisfecha / transporte). NUNCA canario.
    case skipped(reason: String)
    /// 401 de `/sync/merkle`: la sesión de la nube ya no vale. Esperar no la renueva — la renueva la persona.
    ///
    /// **Es un caso propio desde el ticket `reverse-verify-network-bucket-hides-a-definitive-server-no`**, y hasta
    /// ese día salía como `.skipped(reason: "fetch-failed")`: el mapping lo leía como red y la vuelta a iCloud se
    /// quedaba TRES DÍAS en «Comprobando que todo llegó…» ante un «no» que ya era definitivo. Se tipa aquí, donde
    /// el cliente ya lo distinguía, y no en el consumidor: el push y el pull lo hacen así desde siempre.
    case sessionExpired
    /// 403 de `/sync/merkle`: la cuenta en la nube no está disponible. Tampoco se arregla esperando. Mismo ticket
    /// y mismo porqué que `.sessionExpired`.
    case accountUnavailable
}

extension CloudSyncEngine {

    /// Verifica la integridad del Canal 1 contra el backend (I8f-3).
    ///
    /// GUARD A-3 (load-bearing): un delta local pendiente (outbox VIVO ≠ 0 — incluye filas con syncID
    /// jamás pusheadas que el drain encoló) o un ciclo de pull que no terminó `.completed` produce
    /// divergencia ESPERADA (no incidente) → `.skipped` + breadcrumb `merkleSkippedNotQuiescent`,
    /// jamás canario. El caller I9 decide la cadencia.
    ///
    /// `beforeLocalTree` corre SÍNCRONO justo antes de calcular el árbol local, ya pasado el `await` del remoto. Lo pasa la
    /// verificación de la ida para devolver las identidades que el espejo cambió durante esa espera
    /// (`MigrationWorkExecutor.restoreRelayIdentities`). Si lanza, es una lectura local que falló: el mismo skip que el
    /// cómputo del árbol. `nil` en el runtime y en la vuelta a iCloud.
    func verifyIntegrity(using client: SyncMerkleClient, context: ModelContext,
                         beforeLocalTree: (@MainActor () throws -> Void)? = nil) async -> MerkleVerdict {
        // A-3: quiescencia local.
        let rows: [SyncOutbox]
        do {
            rows = try context.fetch(FetchDescriptor<SyncOutbox>())
        } catch {
            #if DEBUG
            print("CloudSyncEngine.verifyIntegrity: fetch outbox falló: \(error)")
            #endif
            return .skipped(reason: MerkleSkipReason.outboxFetchFailed)
        }
        let liveOutbox = rows.filter { $0.rejectedReason == nil }.count
        guard liveOutbox == 0 else {
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: "outbox-pending:\(liveOutbox)")
            return .skipped(reason: MerkleSkipReason.outboxPending)
        }
        // Fix #3 del review: un DEAD-LETTER persistente representa un delta local que el server NUNCA
        // materializará → el árbol local diverge del remoto EN CADA verificación para siempre, diluyendo
        // la semántica del canario ("pérdida de integridad NO explicada"). El rechazo ya tiene su propio
        // canario (`cloudSyncMutationRejected`) → aquí se SALTA, jamás se compara.
        let deadLetters = rows.count - liveOutbox
        guard deadLetters == 0 else {
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: "dead-letters:\(deadLetters)")
            return .skipped(reason: MerkleSkipReason.deadLetters)
        }
        guard lastPullCycleCompleted else {
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: "no-completed-pull")
            return .skipped(reason: MerkleSkipReason.noCompletedPull)
        }

        // Snapshot remoto. **No se aplana**: el cliente ya distingue 401 / 403 / resto, y colapsarlos aquí en un
        // solo `reason` era lo que hacía que la vuelta a iCloud esperase 72 h ante un «no» definitivo del servidor
        // (ticket `reverse-verify-network-bucket-hides-a-definitive-server-no`). El breadcrumb se conserva EN LOS
        // TRES para no perder el rastro que ya existía.
        let outcome = await client.fetchMerkle()
        let remote: RemoteMerkle
        switch outcome {
        case .snapshot(let snapshot):
            remote = snapshot
        case .sessionExpired:
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: "fetch:\(outcome)")
            return .sessionExpired
        case .accountUnavailable:
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: "fetch:\(outcome)")
            return .accountUnavailable
        case .transient:
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: "fetch:\(outcome)")
            return .skipped(reason: MerkleSkipReason.fetchFailed)
        }
        // Fix #1 del review: NUNCA comparar árboles de contratos distintos. Un server en un canon
        // futuro (c2) o respondiendo a otro capability-set produciría divergencia FALSA PERMANENTE —
        // debe ser un skip limpio, no un canario.
        guard remote.canonVersion == "c1" else {
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: "canon-version:\(remote.canonVersion)")
            return .skipped(reason: MerkleSkipReason.canonVersionMismatch)
        }
        guard remote.capabilitySet == SyncPullClient.capabilitySet else {
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: "capability-set:\(remote.capabilitySet)")
            return .skipped(reason: MerkleSkipReason.capabilitySetMismatch)
        }

        // Árbol local + tablas con cuarentena (regla 5: nunca compararlas — el cliente no las
        // materializa; compararlas sería divergencia falsa garantizada).
        //
        // El cómputo local LANZA desde el 2026-09-22 (ticket
        // `verify-reads-a-failed-local-fetch-as-an-empty-outbox`): hasta ese día una tabla que no se dejaba leer
        // entraba al ensamblado con el hash del corpus VACÍO, indistinguible de una tabla sin filas, y salía de
        // aquí como `.diverged` — una pérdida de integridad inventada, con su canario y, en la vuelta a iCloud,
        // consumiendo el presupuesto de MISMATCH hasta `reverseFailedRollback`.
        let local: SyncMerkle.LocalMerkle
        do {
            try beforeLocalTree?()
            local = try SyncMerkle.computeLocalMerkle(context: context)
        } catch {
            #if DEBUG
            print("CloudSyncEngine.verifyIntegrity: cómputo del árbol local falló: \(error)")
            #endif
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: MerkleSkipReason.localMerkleFetchFailed)
            return .skipped(reason: MerkleSkipReason.localMerkleFetchFailed)
        }
        let quarantinedTables: Set<String>
        do {
            quarantinedTables = Set(try context.fetch(FetchDescriptor<SyncQuarantine>()).map(\.entityType))
        } catch {
            #if DEBUG
            print("CloudSyncEngine.verifyIntegrity: fetch quarantine falló: \(error)")
            #endif
            return .skipped(reason: MerkleSkipReason.quarantineFetchFailed)
        }

        var diverged: [String] = []
        for table in EntityApplyMap.wiredTables.sorted() {
            if quarantinedTables.contains(table) {
                // Defensivo: la cuarentena solo guarda tablas NO cableadas hoy; si una cableada
                // apareciera (drift futuro), saltarla es lo honesto.
                CloudSyncBreadcrumb.merkleEntitySkippedQuarantined(entity: table)
                continue
            }
            guard let localEntity = local.entities[table] else { continue }
            if remote.entities[table]?.hash != localEntity.hashHex {
                diverged.append(table)
                CloudSyncBreadcrumb.merkleDivergence(entity: table)
                MetricsService.cloudSyncMerkleDivergence(entity: table)
            }
        }
        // Root global SOLO sin cuarentena (con cuarentena hay filas server-side no materializables →
        // el root diverge por diseño, no por incidente).
        if diverged.isEmpty, quarantinedTables.isEmpty, remote.root != local.rootHex {
            diverged.append("root")
            CloudSyncBreadcrumb.merkleDivergence(entity: "root")
            MetricsService.cloudSyncMerkleDivergence(entity: "root")
        }

        if diverged.isEmpty {
            CloudSyncBreadcrumb.merkleConverged(entities: EntityApplyMap.wiredTables.count)
            return .converged
        }
        return .diverged(entities: diverged)
    }
}

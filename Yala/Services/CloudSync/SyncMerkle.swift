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

@MainActor
enum SyncMerkle {

    /// Columnas emitidas que NO entran al leaf del Canal 1 (A-2b). Simétrico con `canon.ts`.
    nonisolated static let channel1ExcludedColumns: Set<String> = ["local_day"]

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
    static func computeLocalMerkle(context: ModelContext) -> LocalMerkle {
        var digests: [String: Data] = [:]
        var entities: [String: EntitySummary] = [:]

        // Las 16 tablas del manifest parten como vacías (hash de "").
        for table in EntityEmissionMap.catalog.keys {
            digests[table] = emptyDigest
            entities[table] = EntitySummary(count: 0, hashHex: hexString(emptyDigest))
        }

        let overrides = danglingOverrides(context: context)

        // Las cableadas se computan de verdad (dispatch CONCRETO por tipo). D1: la identidad de sync es
        // `syncID` (las 6 sintéticas) o `id` (las cableadas en I12) — se pasa como closure.
        let computed: [(String, [(String, Data)])] = [
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
    private static func danglingOverrides(context: ModelContext) -> [UUID: [String: UUID]] {
        var overrides: [UUID: [String: UUID]] = [:]
        do {
            for dangler in try context.fetch(FetchDescriptor<SyncDanglingRef>()) {
                overrides[dangler.rowSyncID, default: [:]][dangler.column] = dangler.targetUUID
            }
        } catch {
            #if DEBUG
            print("SyncMerkle.danglingOverrides fetch falló: \(error)")
            #endif
        }
        return overrides
    }

    /// Leaves de UNA entidad cableada. Una fila cuyo payload el codec rechaza (dato no-canonicalizable;
    /// tampoco habría podido pushearse — el drain la descarta con canario) se SALTA con rastro: mejor
    /// una divergencia detectable que un crash del verificador (hueco documentado v1).
    private static func collectLeaves<M: PersistentModel>(
        _ type: M.Type, emission: EntityEmission<M>, identity: (M) -> UUID?,
        overrides: [UUID: [String: UUID]], context: ModelContext
    ) -> [(String, Data)] {
        let models: [M]
        do {
            models = try context.fetch(FetchDescriptor<M>())
        } catch {
            #if DEBUG
            print("SyncMerkle.collectLeaves<\(M.self)> fetch falló: \(error)")
            #endif
            return []
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

/// Veredicto de una verificación de integridad. La REMEDIACIÓN (re-pull reconciliado de la tabla
/// divergente) NO se dispara automática en I8f-3 — es wiring de I9; el verdict la habilita.
enum MerkleVerdict: Equatable {
    case converged
    /// Tablas cuyo entityHash local ≠ remoto (o `"root"` si solo divergió el root global).
    case diverged(entities: [String])
    /// No se verificó (precondición A-3 no satisfecha / transporte). NUNCA canario.
    case skipped(reason: String)
}

extension CloudSyncEngine {

    /// Verifica la integridad del Canal 1 contra el backend (I8f-3).
    ///
    /// GUARD A-3 (load-bearing): un delta local pendiente (outbox VIVO ≠ 0 — incluye filas con syncID
    /// jamás pusheadas que el drain encoló) o un ciclo de pull que no terminó `.completed` produce
    /// divergencia ESPERADA (no incidente) → `.skipped` + breadcrumb `merkleSkippedNotQuiescent`,
    /// jamás canario. El caller I9 decide la cadencia.
    func verifyIntegrity(using client: SyncMerkleClient, context: ModelContext) async -> MerkleVerdict {
        // A-3: quiescencia local.
        let rows: [SyncOutbox]
        do {
            rows = try context.fetch(FetchDescriptor<SyncOutbox>())
        } catch {
            #if DEBUG
            print("CloudSyncEngine.verifyIntegrity: fetch outbox falló: \(error)")
            #endif
            return .skipped(reason: "outbox-fetch-failed")
        }
        let liveOutbox = rows.filter { $0.rejectedReason == nil }.count
        guard liveOutbox == 0 else {
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: "outbox-pending:\(liveOutbox)")
            return .skipped(reason: "outbox-pending")
        }
        // Fix #3 del review: un DEAD-LETTER persistente representa un delta local que el server NUNCA
        // materializará → el árbol local diverge del remoto EN CADA verificación para siempre, diluyendo
        // la semántica del canario ("pérdida de integridad NO explicada"). El rechazo ya tiene su propio
        // canario (`cloudSyncMutationRejected`) → aquí se SALTA, jamás se compara.
        let deadLetters = rows.count - liveOutbox
        guard deadLetters == 0 else {
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: "dead-letters:\(deadLetters)")
            return .skipped(reason: "dead-letters")
        }
        guard lastPullCycleCompleted else {
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: "no-completed-pull")
            return .skipped(reason: "no-completed-pull")
        }

        // Snapshot remoto.
        let outcome = await client.fetchMerkle()
        guard case .snapshot(let remote) = outcome else {
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: "fetch:\(outcome)")
            return .skipped(reason: "fetch-failed")
        }
        // Fix #1 del review: NUNCA comparar árboles de contratos distintos. Un server en un canon
        // futuro (c2) o respondiendo a otro capability-set produciría divergencia FALSA PERMANENTE —
        // debe ser un skip limpio, no un canario.
        guard remote.canonVersion == "c1" else {
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: "canon-version:\(remote.canonVersion)")
            return .skipped(reason: "canon-version-mismatch")
        }
        guard remote.capabilitySet == SyncPullClient.capabilitySet else {
            CloudSyncBreadcrumb.merkleSkippedNotQuiescent(reason: "capability-set:\(remote.capabilitySet)")
            return .skipped(reason: "capability-set-mismatch")
        }

        // Árbol local + tablas con cuarentena (regla 5: nunca compararlas — el cliente no las
        // materializa; compararlas sería divergencia falsa garantizada).
        let local = SyncMerkle.computeLocalMerkle(context: context)
        let quarantinedTables: Set<String>
        do {
            quarantinedTables = Set(try context.fetch(FetchDescriptor<SyncQuarantine>()).map(\.entityType))
        } catch {
            #if DEBUG
            print("CloudSyncEngine.verifyIntegrity: fetch quarantine falló: \(error)")
            #endif
            return .skipped(reason: "quarantine-fetch-failed")
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

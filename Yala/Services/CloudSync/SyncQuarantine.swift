//
//  SyncQuarantine.swift
//  Yala
//
//  Cuarentena de deltas remotos NO materializables (Modo Nube, incremento I8f-1). Un delta que baja
//  del pull (`GET /sync/pull`) pero cuya `entity_type` (tabla Postgres) aún no está CABLEADA al apply
//  local —las 10 entidades de las 16 que todavía no llevan `syncID` local (Account/Subcategory/Tag/…)—
//  no puede escribirse a un `@Model` todavía. El contrato del apply (§d.6, D-5) prohíbe el tercer
//  camino "descartar y avanzar": TODO delta o se aplica a su `@Model` o se ENCOLA aquí VERBATIM.
//
//  IMPORTANTE — NUNCA se espeja a CloudKit: vive en el store sync-meta con `cloudKitDatabase: .none`
//  (ver `SwiftDataConfiguration.syncMetaConfiguration`). Es cola LOCAL por dispositivo.
//
//  Dedup por `serverSeq` (clave del eje de orden global del pull): re-pull de una página tras un crash
//  (cursor no avanzó) NO duplica la fila cuarentenada (idempotencia §d.6, D-5). El `rawDelta` guarda el
//  `PulledDelta` re-serializado de forma DETERMINISTA (round-trippea al struct de wire) para que el
//  drenaje del upgrade path (I9) lo re-aplique cuando esa entidad gane identidad local — NO es de este
//  incremento (aquí solo el encolado + dedup).
//
//  §d.5 A1: si esta tabla se RECREARA por lightweight migration (renombrar la clase), el testigo A1
//  `schemaVersion` lo delata en runtime; el guard de recuperación (FORZAR `serverSeqCursor=0` para
//  re-pull completo) se cablea en I9 — aquí queda el hook `CloudSyncEngine.resetServerSeqCursor()`.
//

import Foundation
import SwiftData

extension CloudSyncSchemaVersions {
    /// Versión de schema de `SyncQuarantine` (testigo A1 en cada fila). v1 (I8f-1).
    static let syncQuarantine = 1
}

/// Fila de cuarentena de un delta remoto aún no materializable. Una por `serverSeq` (dedup).
@Model
final class SyncQuarantine {

    /// Posición del delta en el eje de orden GLOBAL del pull (`server_seq`). Clave de dedup: re-pull de
    /// la misma página tras un crash no duplica. `Int64` (el seq puede crecer sin techo de 32 bits).
    var serverSeq: Int64 = 0

    /// `entity_type` del delta = el NOMBRE DE TABLA Postgres (ej. `"accounts"`), no la clase Swift.
    var entityType: String = ""

    /// Identidad de sync de la fila remota (`sync_id`). Se conserva para el drenaje del upgrade path.
    var syncID: UUID = UUID()

    /// El `PulledDelta` re-serializado (JSON determinista, keys ordenadas) — round-trippea al struct de
    /// wire. NO byte-verbatim del socket (JSONSerialization no preserva layout) pero re-decodable sin
    /// pérdida por el mismo decoder del pull.
    var rawDelta: String = ""

    /// HLC de FILA del delta (46 chars c1) — para el árbitro LWW cuando el upgrade path lo re-aplique.
    var hlc: String = ""

    /// Cuándo se cuarentenó la fila (diagnóstico/orden de inserción, NO la verdad temporal — esa es `hlc`).
    var createdAt: Date = Date.now

    /// Versión del schema bajo la que se materializó esta fila (testigo A1).
    var schemaVersion: Int = CloudSyncSchemaVersions.syncQuarantine

    init(
        serverSeq: Int64,
        entityType: String,
        syncID: UUID,
        rawDelta: String,
        hlc: String,
        createdAt: Date = .now,
        schemaVersion: Int = CloudSyncSchemaVersions.syncQuarantine
    ) {
        self.serverSeq = serverSeq
        self.entityType = entityType
        self.syncID = syncID
        self.rawDelta = rawDelta
        self.hlc = hlc
        self.createdAt = createdAt
        self.schemaVersion = schemaVersion
    }
}

//
//  SyncOutbox.swift
//  Yala
//
//  Cola de mutaciones salientes del Modo Nube (incremento I3). Cada fila es UNA operación de
//  dominio (upsert / tombstone) capturada del SwiftData History y lista para reenviarse al backend
//  (el sender llega en I8). El `CloudSyncEngine` la produce leyendo el History (write→drain); nada
//  de producción la instancia todavía (DARK — el wiring llega en I9/I12).
//
//  IMPORTANTE — NUNCA se espeja a CloudKit: vive en el store sync-meta con `cloudKitDatabase: .none`
//  (ver `SwiftDataConfiguration.syncMetaConfiguration`). Es la cola LOCAL de salida del dispositivo.
//
//  INVARIANTE §d.5 — el `hlc` se FIJA al crear la fila y NUNCA se regenera. "Resumibilidad" del sync
//  = reenviar la misma fila con su HLC fijo; regenerarlo rompería el orden total / la deduplicación
//  aguas abajo. Por eso el HLC es la fuente de verdad temporal de la operación, no `createdAt`.
//
//  `fieldsJSON` es el `fields` del delta serializado por el codec canónico c1 (I8a) — dominio limpio,
//  PATCH parcial, SIN `syncID` (es la PK del upsert, no columna de dominio). `fieldHlcsJSON` es el
//  `field_hlcs` (mapa unidad-de-coherencia → HLC, §d.4bis) como JSON plano `{unit:hlc}`. Ambos van
//  vacíos/`nil` en filas `tombstone` (el borrado no lleva payload de campos). I8c los produce vía
//  `DeltaEmitter` + `Canonc1Codec`.
//

import Foundation
import SwiftData

/// Operación de dominio que representa una fila del outbox.
nonisolated enum SyncOutboxOp: String {
    /// Alta o modificación de una entidad (insert/update del History).
    case upsert
    /// Borrado de una entidad (delete del History; identidad vía tombstone `.preserveValueOnDeletion`).
    case tombstone
}

/// Taxonomía de la razón de un tombstone (§c.1). Es METADATA DE AUDITORÍA aguas abajo (el backend
/// mantiene `deleted=true` igual sea cual sea el reason) → una clasificación conservadora NO
/// compromete la correctness. La clasificación es 100% DRAIN-SIDE (`CloudSyncEngine.classify*`): los
/// ~30 call-sites de delete de producción NO se tocan.
nonisolated enum SyncTombstoneReason: String {
    /// Borrado directo pedido por el usuario (default cuando no hay señal de cascada/migración).
    case user
    /// Borrado en cascada: el delete llegó en una transacción de History que TAMBIÉN borra un tipo
    /// PADRE de cascada conocida (hoy `ScheduledPayment` → sus TX/drafts futuros; `EntityDeletionService`).
    case cascade
    /// Deduplicación de categorías (I9: `CategoryDeduplicationService` marcará un author dedicado; hasta
    /// entonces esos deletes caen en `user`/`cascade`).
    case dedup
    /// Borrado emitido por el motor/migración (I10). Bucket por completitud — de facto inalcanzable hoy
    /// (los writes del motor se descartan por echo-suppression antes de clasificar).
    case migration
    /// Vaciado total de datos (I12: `DataWipeService` marcará un author dedicado; hasta entonces esos
    /// deletes caen en `user`/`cascade`).
    case wipe
}

extension CloudSyncSchemaVersions {
    /// Versión de schema de `SyncOutbox` (testigo A1 en cada fila). v2 (I4): añade `tombstoneReason`.
    /// v3 (I8c): añade `fieldHlcsJSON` (el `field_hlcs` por-unidad, additive). v4 (I8e): añade el
    /// dead-letter (`rejectedReason`/`rejectedAt`, ambos additive-optional).
    static let syncOutbox = 4
}

/// Fila de la cola de salida. Una por operación de dominio pendiente de sincronizar.
@Model
final class SyncOutbox {

    /// Identidad estable de sync de la entidad mutada (el `syncID` que la fila de negocio espeja).
    /// Para upsert es la PK; para tombstone es la identidad a borrar (preservada del tombstone).
    var syncID: UUID = UUID()

    /// Tipo de entidad (`SyncEntityType.*`). Discrimina el codec/tabla destino aguas abajo.
    var entityType: String = ""

    /// Operación (`SyncOutboxOp.rawValue`): "upsert" | "tombstone".
    var opRaw: String = ""

    /// HLC canónico c1 (46 chars). FIJADO al crear — NUNCA se regenera (invariante §d.5).
    var hlc: String = ""

    /// Identidad única de esta mutación concreta (idempotencia end-to-end en el backend; I8).
    var clientMutationID: UUID = UUID()

    /// Payload de campos: el `fields` del delta (dominio limpio, PATCH parcial) serializado por el codec
    /// canónico c1. `"{}"` en filas `tombstone`.
    var fieldsJSON: String = ""

    /// `field_hlcs` del delta: JSON plano `{unit:hlc}` (unidad de coherencia → HLC, §d.4bis). `nil` en
    /// filas `tombstone` (el árbitro es `hlc`/`deleted_hlc`). Additive (v3).
    var fieldHlcsJSON: String?

    /// Razón del tombstone (`SyncTombstoneReason.rawValue`) — `nil` en filas `upsert`. Metadata de
    /// auditoría: el backend no ramifica sobre ella (aplica `deleted=true` igual). Additive (v2).
    var tombstoneReason: String?

    /// Autor de la mutación de origen (el `author` de la transacción de History que la produjo;
    /// cadena vacía para writes locales sin autor). Distinto del autor del CONTEXTO con que el motor
    /// persiste el outbox (`CloudSyncEngine.outboxSaveAuthor`), que sirve para la anti-auto-captura.
    var author: String = ""

    /// Cuándo se encoló la fila. Diagnóstico/orden de inserción — NO es la verdad temporal (esa es `hlc`).
    var createdAt: Date = Date.now

    /// DEAD-LETTER (I8e, §d.5 cero-silencios): motivo por el que el backend RECHAZÓ este delta (el
    /// `reason` del `SyncDeltaResult` con `status == rejected`, p.ej. `coherence_group_partial:money`).
    /// `nil` = nunca rechazado. La fila NO se purga al rechazarse (a diferencia de `applied`/`noop`): queda
    /// aquí con su motivo para que el panel DEBUG (I12) la superficie; un rechazo repetido re-escribe el
    /// mismo motivo (no se pierde). Additive-optional (v4). Un `coherence_group_partial` en v1 = bug de
    /// emisión (debe ser 0 tras I8b/I8c) — el canario `cloudSyncMutationRejected` lo delata.
    var rejectedReason: String?

    /// Cuándo el backend rechazó este delta por última vez (par de `rejectedReason`). Additive-optional (v4).
    var rejectedAt: Date?

    /// Versión del schema bajo la que se materializó esta fila (testigo A1).
    var schemaVersion: Int = CloudSyncSchemaVersions.syncOutbox

    init(
        syncID: UUID,
        entityType: String,
        op: SyncOutboxOp,
        hlc: String,
        clientMutationID: UUID = UUID(),
        fieldsJSON: String,
        fieldHlcsJSON: String? = nil,
        author: String,
        tombstoneReason: String? = nil,
        createdAt: Date = .now,
        rejectedReason: String? = nil,
        rejectedAt: Date? = nil,
        schemaVersion: Int = CloudSyncSchemaVersions.syncOutbox
    ) {
        self.syncID = syncID
        self.entityType = entityType
        self.opRaw = op.rawValue
        self.hlc = hlc
        self.clientMutationID = clientMutationID
        self.fieldsJSON = fieldsJSON
        self.fieldHlcsJSON = fieldHlcsJSON
        self.author = author
        self.tombstoneReason = tombstoneReason
        self.createdAt = createdAt
        self.rejectedReason = rejectedReason
        self.rejectedAt = rejectedAt
        self.schemaVersion = schemaVersion
    }
}

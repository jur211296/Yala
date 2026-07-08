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
//  `fieldsJSON` es HOY un STUB estructurado (ver `CloudSyncEngine`): un JSON `{prop: descripción}`
//  de las propiedades cambiadas, SIN `syncID` (es la PK del upsert, no una columna de dominio). I8 lo
//  reemplaza por el codec canónico c1.
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

extension CloudSyncSchemaVersions {
    /// Versión de schema de `SyncOutbox` (testigo A1 en cada fila).
    static let syncOutbox = 1
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

    /// Payload de campos. HOY STUB (`{prop: descripción}` sin `syncID`); I8 → codec canónico c1.
    var fieldsJSON: String = ""

    /// Autor de la mutación de origen (el `author` de la transacción de History que la produjo;
    /// cadena vacía para writes locales sin autor). Distinto del autor del CONTEXTO con que el motor
    /// persiste el outbox (`CloudSyncEngine.outboxSaveAuthor`), que sirve para la anti-auto-captura.
    var author: String = ""

    /// Cuándo se encoló la fila. Diagnóstico/orden de inserción — NO es la verdad temporal (esa es `hlc`).
    var createdAt: Date = Date.now

    /// Versión del schema bajo la que se materializó esta fila (testigo A1).
    var schemaVersion: Int = CloudSyncSchemaVersions.syncOutbox

    init(
        syncID: UUID,
        entityType: String,
        op: SyncOutboxOp,
        hlc: String,
        clientMutationID: UUID = UUID(),
        fieldsJSON: String,
        author: String,
        createdAt: Date = .now,
        schemaVersion: Int = CloudSyncSchemaVersions.syncOutbox
    ) {
        self.syncID = syncID
        self.entityType = entityType
        self.opRaw = op.rawValue
        self.hlc = hlc
        self.clientMutationID = clientMutationID
        self.fieldsJSON = fieldsJSON
        self.author = author
        self.createdAt = createdAt
        self.schemaVersion = schemaVersion
    }
}

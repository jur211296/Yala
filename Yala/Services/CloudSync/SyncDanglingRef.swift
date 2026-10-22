//
//  SyncDanglingRef.swift
//  Yala
//
//  Registro durable de un `_ref` SINGULAR remoto que NO resolvió al aplicarse (Modo Nube, I8f-1,
//  fix F-2 del review adversarial). Con materialized-rows el orden por `server_seq` NO es causal
//  (una Category editada re-estampa un seq MAYOR que la TX que la referencia) → una TX puede llegar
//  ANTES que su Category y el `_ref` se pone `nil`. Sin este registro, un crash entre páginas hace
//  el huérfano PERMANENTE (a diferencia de `tag_refs`, cuyo CSV mirror preserva los UUIDs y
//  auto-cura). El pase de re-resolución al final de `pullAndApplyOnce` consume estas filas: target
//  ya local → setea la relación y borra el dangler; fila origen borrada → borra el dangler; target
//  aún ausente → lo deja (reintento en el próximo ciclo).
//
//  IMPORTANTE — NUNCA se espeja a CloudKit: vive en el store sync-meta con `cloudKitDatabase: .none`.
//  Dedup por `(rowSyncID, column)`: un delta más nuevo de la misma fila REEMPLAZA el `targetUUID`.
//

import Foundation
import SwiftData

extension CloudSyncSchemaVersions {
    /// Versión de schema de `SyncDanglingRef` (testigo A1 en cada fila). v1 (I8f-1).
    static let syncDanglingRef = 1
}

/// Una referencia singular colgada: la fila `rowSyncID` de `entityTable` apuntó a `targetUUID` en
/// `column` y el destino aún no existe localmente.
@Model
final class SyncDanglingRef {

    /// Tabla Postgres de la fila ORIGEN (ej. `"tx_items"`) — discrimina el dispatch de re-resolución.
    var entityTable: String = ""

    /// `syncID` de la fila origen (la que tiene el `_ref` en nil).
    var rowSyncID: UUID = UUID()

    /// Columna del `_ref` colgado (ej. `"category_ref"`). Junto a `rowSyncID` forma la clave de dedup.
    var column: String = ""

    /// UUID del destino según el WIRE (la verdad remota que se preserva para re-resolver).
    var targetUUID: UUID = UUID()

    /// Cuándo se registró el dangler (diagnóstico).
    var createdAt: Date = Date.now

    /// Versión del schema bajo la que se materializó esta fila (testigo A1).
    var schemaVersion: Int = CloudSyncSchemaVersions.syncDanglingRef

    init(
        entityTable: String,
        rowSyncID: UUID,
        column: String,
        targetUUID: UUID,
        createdAt: Date = .now,
        schemaVersion: Int = CloudSyncSchemaVersions.syncDanglingRef
    ) {
        self.entityTable = entityTable
        self.rowSyncID = rowSyncID
        self.column = column
        self.targetUUID = targetUUID
        self.createdAt = createdAt
        self.schemaVersion = schemaVersion
    }
}

//
//  GroupSyncOutbox.swift
//  Yala
//
//  Cola de mutaciones salientes del canal de sync de GRUPOS → backend (incremento G2). Molde
//  ESTRUCTURAL de `SyncOutbox` (el outbox personal) + `groupID: String` (el `group_id` del wire de
//  Grupos, §A). Cada fila es UNA operación de dominio (upsert / tombstone) de una de las 4 entidades
//  EMISIBLES de Grupos (`SplitGroup` update-only, `SplitExpense`, `SplitShare`, `SplitSettlement`)
//  capturada del SwiftData History por `GroupsSyncClient` y lista para `POST /groups/push`.
//
//  `SplitMember` es PULL-ONLY (§A.1 `pull_only:true`): el cliente JAMÁS la empuja → nunca llega a esta
//  cola (el drain de emisión la EXCLUYE aunque esté en `groupEntityNames` para el muro anti-fuga).
//
//  IMPORTANTE — NUNCA se espeja a CloudKit: vive en el store sync-meta con `cloudKitDatabase: .none`
//  (ver `SwiftDataConfiguration.syncMetaConfiguration`). Es la cola LOCAL de salida del dispositivo.
//
//  INVARIANTE §d.5 (heredada del outbox personal) — el `hlc` se FIJA al crear la fila y NUNCA se
//  regenera. "Resumibilidad" del sync = reenviar la misma fila con su HLC fijo.
//
//  Identidad: para `SplitExpense/SplitShare/SplitSettlement` `syncID` = su `id` (UUID) y `groupID` =
//  `groupZoneID`. Para `SplitGroup` `syncID` = su `id` (para dedup local) y `groupID` = `cloudKitZoneID`
//  (el `group_id` del wire); el push emite `sync_id = null` para `split_groups` (§A.2 rama especial).
//

import Foundation
import SwiftData

extension CloudSyncSchemaVersions {
    /// Versión de schema de `GroupSyncOutbox` (testigo A1 en cada fila). Día-1 del canal de Grupos (G2). **2 desde el
    /// 2026-09-28**: la fila nació con su dueño ya decidido (`ownerUserID`, ticket
    /// `groups-outbox-rows-without-a-live-session-have-no-exit`). Una fila de versión 1 es de un build anterior, y solo a ésa
    /// se le busca dueño después (`GroupsSyncClient.adoptOwnersForUnownedRows`): una de versión 2 sin dueño se quedó así a
    /// propósito, y dárselo luego se lo daría a quien tenga la sesión.
    static let groupSyncOutbox = 2
    /// La versión de las filas de antes del dueño por fila.
    static let groupSyncOutboxBeforeOwners = 1
}

/// Fila de la cola de salida del canal de Grupos. Una por operación de dominio pendiente de sincronizar.
@Model
final class GroupSyncOutbox {

    /// Identidad estable de sync de la entidad mutada (el `id` de la fila `Split*`). Para `SplitGroup` es
    /// su `id` local (dedup); el wire emite `sync_id=null` para `split_groups` (el `group_id` es la PK).
    var syncID: UUID = UUID()

    /// `group_id` del wire (§A): `groupZoneID` para expense/share/settlement, `cloudKitZoneID` para el grupo.
    var groupID: String = ""

    /// Tipo de entidad (`GroupSyncEntityType.*` = nombre de clase). Discrimina el codec/tabla destino.
    var entityType: String = ""

    /// Operación (`SyncOutboxOp.rawValue`): "upsert" | "tombstone".
    var opRaw: String = ""

    /// HLC canónico c1 (46 chars). FIJADO al crear — NUNCA se regenera (invariante §d.5).
    var hlc: String = ""

    /// Identidad única de esta mutación concreta (idempotencia end-to-end en el backend).
    var clientMutationID: UUID = UUID()

    /// Payload de campos: el `fields` del delta (dominio limpio, PATCH parcial) serializado por el codec
    /// canónico c1. `"{}"` en filas `tombstone`.
    var fieldsJSON: String = ""

    /// `field_hlcs` del delta: JSON plano `{unit:hlc}` (unidad de coherencia → HLC). `nil` en tombstone.
    var fieldHlcsJSON: String?

    /// Razón del tombstone (`SyncTombstoneReason.rawValue`) — `nil` en filas `upsert`. Auditoría.
    var tombstoneReason: String?

    /// Autor de la transacción de History que la produjo (diagnóstico; distinto del autor del CONTEXTO
    /// con que `GroupsSyncClient` persiste el outbox, `GroupsSyncClient.outboxSaveAuthor`).
    var author: String = ""

    /// Cuándo se encoló la fila. Diagnóstico/orden de inserción — NO es la verdad temporal (esa es `hlc`).
    var createdAt: Date = Date.now

    /// DEAD-LETTER (cero-silencios): motivo por el que el backend RECHAZÓ este delta. `nil` = nunca rechazado.
    var rejectedReason: String?

    /// Cuándo el backend rechazó este delta por última vez (par de `rejectedReason`).
    var rejectedAt: Date?

    /// Versión del schema bajo la que se materializó esta fila (testigo A1).
    var schemaVersion: Int = CloudSyncSchemaVersions.groupSyncOutbox

    /// **De quién es este cambio**: el `sub` de la cuenta que lo apuntó (ticket
    /// `groups-outbox-rows-without-a-live-session-have-no-exit`). Lo estampa el drain con
    /// `GroupsOutboxOwnershipLogic.owner`, y **nadie lo re-sella después**. `pushPending` solo sube las filas cuyo dueño es
    /// la sesión viva: las de otra cuenta se quedan para su dueño o para el descarte avisado del cierre, nunca se suben
    /// firmadas por quien entró después.
    ///
    /// `nil` = dueño sin probar: una fila de un build anterior sin entrada en el espejo del App Group, o una capturada sin
    /// sesión en un teléfono en el que el canal nunca vio una. Tampoco se sube con una sesión: retener gana a reatribuir.
    var ownerUserID: String?

    init(
        syncID: UUID,
        groupID: String,
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
        schemaVersion: Int = CloudSyncSchemaVersions.groupSyncOutbox,
        ownerUserID: String? = nil
    ) {
        self.syncID = syncID
        self.groupID = groupID
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
        self.ownerUserID = ownerUserID
    }
}

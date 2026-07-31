//
//  GroupSyncCursor.swift
//  Yala
//
//  Cursor persistente del pipeline de captura/aplicación del canal de sync de GRUPOS (incremento G2).
//  Fila ÚNICA (single-row) en el store sync-meta: recuerda hasta dónde avanzó `GroupsSyncClient`
//  leyendo el SwiftData History (drain), su reloj HLC durable, y el `server_seq` POR GRUPO del pull.
//
//  IMPORTANTE — NUNCA se espeja a CloudKit: vive en el store sync-meta con `cloudKitDatabase: .none`.
//  Es estado LOCAL por dispositivo.
//
//  Espeja `SyncCursor` (personal) con dos diferencias:
//   - El pull de Grupos es MULTI-GRUPO: en vez de un `serverSeqCursor` escalar, `groupCursorsJSON`
//     guarda `{group_id: server_seq}` (un cursor por grupo del que el device es writer, §A.3).
//   - El token de History + `lastDrainedTxAt` son PROPIOS del canal de Grupos (el drain de Grupos y el
//     personal leen el MISMO History por-container pero con anclas independientes).
//

import Foundation
import SwiftData

extension CloudSyncSchemaVersions {
    /// Versión de schema de `GroupSyncCursor` (testigo A1 en la fila). Día-1 del canal de Grupos (G2).
    static let groupSyncCursor = 1
}

/// Cursor single-row del pipeline del canal de Grupos. Debe existir a lo sumo UNA fila (el cliente la
/// crea perezosamente y la reusa).
@Model
final class GroupSyncCursor {

    /// `DefaultHistoryToken` codificado (JSON) — hasta dónde procesó el History el drain de Grupos.
    /// `nil` = aún no se ha procesado nada (primer drain → escaneo completo del History).
    var historyTokenData: Data?

    /// `storeIdentifier` del store al que pertenece `historyTokenData`. Un `DefaultHistoryToken` es
    /// POR-STORE: `fetchHistory(predicate: $0.token > token)` devuelve lo posterior DEL STORE de ese
    /// token y OCULTA por completo los demás stores del container, así que un token anclado en el store
    /// PERSONAL deja al canal de Grupos ciego a su propio store para siempre. Este campo es la PROCEDENCIA
    /// del ancla: `nil` = desconocida (fila escrita por un build anterior a este fix, o ancla aún no
    /// establecida) ⇒ `historyTokenData` NO es utilizable y el drain re-escanea para re-anclar.
    var historyTokenStoreID: String?

    /// TIMESTAMP de la última transacción de History consumida por el drain — se persiste en el MISMO
    /// `save()` que avanza `historyTokenData`. Ancla COMPARABLE CROSS-MOUNT del guard de validación del
    /// token (molde `SyncCursor.lastDrainedTxAt` / HALLAZGO 2): el `DefaultHistoryToken` no es comparable
    /// de forma fiable entre montajes distintos del store; los timestamps SÍ. `nil` = cursor pre-consumo.
    var lastDrainedTxAt: Date?

    /// Último HLC del `HLCClock` PERSISTIDO (send y receive parten del estado durable). Se persiste en el
    /// MISMO `save()` que avanza el token → un crash revierte reloj y cursor juntos (replay determinista).
    /// `nil` = reloj aún fresco.
    var clockLatestHLC: String?

    /// Cursores del PULL por grupo: JSON `{group_id: server_seq}`. El pull pide, por cada grupo del que el
    /// device es writer, `server_seq > groupCursorsJSON[gid] ?? 0`; tras aplicar una página avanza el gid a
    /// su `max_server_seq` en el MISMO `save()` que aplica → interrumpir a mitad es idempotente.
    var groupCursorsJSON: String = "{}"

    /// Versión del schema bajo la que se materializó esta fila (testigo A1).
    var schemaVersion: Int = CloudSyncSchemaVersions.groupSyncCursor

    init(
        historyTokenData: Data? = nil,
        historyTokenStoreID: String? = nil,
        lastDrainedTxAt: Date? = nil,
        clockLatestHLC: String? = nil,
        groupCursorsJSON: String = "{}",
        schemaVersion: Int = CloudSyncSchemaVersions.groupSyncCursor
    ) {
        self.historyTokenData = historyTokenData
        self.historyTokenStoreID = historyTokenStoreID
        self.lastDrainedTxAt = lastDrainedTxAt
        self.clockLatestHLC = clockLatestHLC
        self.groupCursorsJSON = groupCursorsJSON
        self.schemaVersion = schemaVersion
    }
}

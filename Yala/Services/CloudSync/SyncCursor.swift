//
//  SyncCursor.swift
//  Yala
//
//  Cursor persistente del pipeline de captura del Modo Nube (incremento I3). Fila ÚNICA (single-row)
//  en el store sync-meta: recuerda hasta dónde avanzó el `CloudSyncEngine` leyendo el SwiftData
//  History, de modo que cada `drainOnce` procesa solo el delta nuevo (no re-escanea todo).
//
//  IMPORTANTE — NUNCA se espeja a CloudKit: vive en el store sync-meta con `cloudKitDatabase: .none`
//  (ver `SwiftDataConfiguration.syncMetaConfiguration`). Es estado LOCAL por dispositivo.
//
//  El `historyTokenData` guarda un `DefaultHistoryToken` codificado (es `Codable`) vía `JSONEncoder`.
//  El motor solo AVANZA el token tras persistir las filas del outbox correspondientes (crash-safety:
//  ver `CloudSyncEngine`). Si el token se pierde/expira (migración destructiva, incompatibilidad),
//  el decode/fetch falla → el motor entra al path `historyTokenExpired` (reconcile completo §d.6; en
//  I3 = re-escaneo del History con dedup, el reconcile real llega en I8).
//
//  ADITIVO EN I8: el `serverSeqCursor` del PULL (posición en la cola del backend) se añade como campo
//  nuevo aquí — additive, no requiere tocar este contrato ahora.
//

import Foundation
import SwiftData

extension CloudSyncSchemaVersions {
    /// Versión de schema de `SyncCursor` (testigo A1 en la fila).
    static let syncCursor = 1
}

/// Cursor single-row del pipeline de captura. Debe existir a lo sumo UNA fila (el motor la crea
/// perezosamente y la reusa).
@Model
final class SyncCursor {

    /// `DefaultHistoryToken` codificado (JSON) — hasta dónde se procesó el History. `nil` = aún no se
    /// ha procesado nada (primer drain → escaneo completo).
    var historyTokenData: Data?

    /// Versión del schema bajo la que se materializó esta fila (testigo A1).
    var schemaVersion: Int = CloudSyncSchemaVersions.syncCursor

    init(
        historyTokenData: Data? = nil,
        schemaVersion: Int = CloudSyncSchemaVersions.syncCursor
    ) {
        self.historyTokenData = historyTokenData
        self.schemaVersion = schemaVersion
    }
}

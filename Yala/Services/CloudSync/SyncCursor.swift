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
//  el decode/fetch falla → el motor entra al fallback de token roto (DIFERIDOS #33,
//  `HistoryTokenFallbackLogic`): re-escaneo ACOTADO por `lastDrainedTxAt` (full-rescan solo sin ancla
//  o si el fetch acotado también lanza — el path `historyTokenExpired` de I3 quedó acotado).
//
//  ADITIVO EN I8: el `serverSeqCursor` del PULL (posición en la cola del backend) se añade como campo
//  nuevo aquí — additive, no requiere tocar este contrato ahora.
//

import Foundation
import SwiftData

extension CloudSyncSchemaVersions {
    /// Versión de schema de `SyncCursor` (testigo A1 en la fila). v2 (I9): añade `quarantinePendingCount`
    /// (testigo lockstep de la cuarentena para el guard de recreación, additive).
    static let syncCursor = 2
}

/// Cursor single-row del pipeline de captura. Debe existir a lo sumo UNA fila (el motor la crea
/// perezosamente y la reusa).
@Model
final class SyncCursor {

    /// `DefaultHistoryToken` codificado (JSON) — hasta dónde se procesó el History. `nil` = aún no se
    /// ha procesado nada (primer drain → escaneo completo).
    var historyTokenData: Data?

    /// PULL (I8f-1, §d.6 / D-5): posición en el eje de orden GLOBAL del backend (`server_seq`). El pull
    /// pide `since = serverSeqCursor` y, tras aplicar una página, lo avanza al `max_server_seq` procesado
    /// en el MISMO `save()` que aplica la página → interrumpir a mitad es idempotente (re-pull converge).
    /// Additive (v1→v2 lógico; el testigo A1 `schemaVersion` no se bumpea: el campo trae default).
    var serverSeqCursor: Int64 = 0

    /// PULL/reloj (I8f-1, §d.6 / D-3): último HLC del `HLCClock` PERSISTIDO. El motor CARGA el reloj desde
    /// aquí al arrancar (send y receive parten del estado durable) y lo PERSISTE en el MISMO `save()` que
    /// avanza el history token (drain) o el `serverSeqCursor` (apply) → un crash revierte reloj y cursor
    /// JUNTOS → replay determinista (sin `receive` de un remoto se rompería el lockstep de resumibilidad
    /// del drain). `nil` = reloj aún fresco (nunca se emitió/recibió nada). Additive.
    var clockLatestHLC: String?

    /// TESTIGO LOCKSTEP de la cuarentena (I9, §d.5 A1 / guard de recreación). Cuenta las filas VIVAS de
    /// `SyncQuarantine` y se actualiza en el MISMO `save()` que inserta (apply/quarantineDelta) o borra
    /// (drenaje del upgrade path) filas de cuarentena — nunca por separado. Al arrancar, `witness > 0 &&
    /// COUNT(SyncQuarantine) == 0` delata que una lightweight migration RECREÓ la tabla vacía → el guard
    /// fuerza `serverSeqCursor = 0` (re-pull completo) + resetea el testigo. Es un CONTEO, no la verdad
    /// (la verdad son las filas); si divergiera del conteo real por un bug, el peor caso es un falso
    /// positivo de recreación (re-pull completo, seguro/idempotente) o un falso negativo (la recreación
    /// la cubriría igual el cursor si también se recreó). Additive (v1→v2). `Int64` (sin techo de 32 bits).
    var quarantinePendingCount: Int64 = 0

    /// TIMESTAMP (`DefaultHistoryTransaction.timestamp`) de la última transacción de History consumida por
    /// el drain — se persiste en el MISMO `save()` que avanza `historyTokenData`. Ancla COMPARABLE
    /// CROSS-MOUNT del guard de validación del token (hallazgo 2, corrida device reversa 2026-07-11): el
    /// `DefaultHistoryToken` NO es comparable de forma fiable entre montajes distintos del store
    /// (`.icloud` mirror-ON → `.cloud` mirror-OFF sobre el mismo archivo) → un `token > staleToken` acuñado
    /// en el mount viejo puede EXCLUIR silenciosamente las txs del mount nuevo; los timestamps SÍ son
    /// comparables. `nil` = cursor pre-schema (aún no consumió nada bajo este campo) → el guard hace SKIP
    /// (residual documentado: un token YA roto en un cursor pre-schema no se auto-cura hasta que un drain
    /// puebla el campo; benigno hoy — 0 devices `.cloud` en producción, flags DARK). Additive (v2→v2
    /// lógico; el testigo A1 `schemaVersion` NO se bumpea: el campo trae default `nil`).
    ///
    /// DIFERIDOS #33: además de red del guard, el ancla es LOAD-BEARING para el fallback de token
    /// ROTO (in-decodificable / fetch por token que lanza): acota el re-escaneo a la ventana
    /// `> ancla − slack` en vez de re-emitir el corpus entero con HLC fresco (ver
    /// `CloudSyncEngine.executeBrokenTokenBranch` y sus semánticas/residuales).
    ///
    /// 0b (viabilidad, plan): este campo NO exige deploy de schema CloudKit. `SyncCursor` vive SIEMPRE en
    /// `SwiftDataConfiguration.syncMetaConfiguration` con `cloudKitDatabase: .none` (metadata LOCAL por
    /// dispositivo que NUNCA se espeja); el mirror de un device `.icloud` solo espeja el store PERSONAL
    /// (`.private`), no el sync-meta → un campo nuevo aquí es puramente local (lightweight migration del
    /// store `.none`, sin autocreación en CloudKit).
    var lastDrainedTxAt: Date?

    /// Versión del schema bajo la que se materializó esta fila (testigo A1).
    var schemaVersion: Int = CloudSyncSchemaVersions.syncCursor

    init(
        historyTokenData: Data? = nil,
        serverSeqCursor: Int64 = 0,
        clockLatestHLC: String? = nil,
        quarantinePendingCount: Int64 = 0,
        lastDrainedTxAt: Date? = nil,
        schemaVersion: Int = CloudSyncSchemaVersions.syncCursor
    ) {
        self.historyTokenData = historyTokenData
        self.serverSeqCursor = serverSeqCursor
        self.clockLatestHLC = clockLatestHLC
        self.quarantinePendingCount = quarantinePendingCount
        self.lastDrainedTxAt = lastDrainedTxAt
        self.schemaVersion = schemaVersion
    }
}

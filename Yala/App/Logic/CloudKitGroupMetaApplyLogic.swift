//
//  CloudKitGroupMetaApplyLogic.swift
//  Yala
//
//  Decisión PURA de `SplitSyncManager.applyGroupMeta`: qué hacer con un `GroupMeta` fetcheado de CloudKit —
//  saltarlo, actualizar una fila existente o insertar una nueva.
//
//  ── Por qué existe este fichero ────────────────────────────────────────────────────────────────────────
//  `applyGroupMeta` es `private` sobre un singleton con `CKSyncEngine` vivo y recibe un `CKRecord` que solo
//  llega por un fetch real: NADA de eso es unit-asertable (CKSyncEngine exige un `CKContainer` con iCloud —
//  device-only, ver la nota de `SplitSyncManagerTests`). Separada aquí, la tabla se prueba entera; el
//  cableado, que es lo que la lógica pura no puede probar, lo fija un source-scan. Molde exacto de
//  `GroupZoneCacheGate` y `GroupsIdentityPurgeGate`.
//
//  ── El defecto que cierra (2026-08-03) ─────────────────────────────────────────────────────────────────
//  `SplitSyncManager.applyGroupMeta` resolvía con `#Predicate { $0.id == modelID }` —identidad LOCAL— y la
//  identidad de un grupo es la ZONA. Una fila born-remote del pull backend nace con un UUID FRESCO y su
//  `cloudKitZoneID` pisado con el `group_id` del server, así que era INVISIBLE a ese fetch ⇒ el canal
//  CloudKit insertaba una GEMELA vía `CKRecordTranslator.group(from:)`, que nunca setea `isBackendGroup` ⇒ el
//  duplicado nacía ya MIXTO. Los otros cuatro `apply*` del manager siguen resolviendo por `id` con razón: la
//  identidad de un gasto, un share, una liquidación o un member SÍ es su `id`.
//
//  ── Alcanzabilidad: ENDURECIMIENTO, no un bug vivo (medido, no inferido) ───────────────────────────────
//  Se enunció como «el PRODUCTOR de la familia» y esa etiqueta no aguanta la medición: el escenario exige un
//  record CloudKit de una zona que YA tiene fila born-backend, y esa misma precondición activa el guard G6-3
//  (`SplitSyncManager:1785`) — la fila born-remote lleva `isBackendGroup = true` y su `cloudKitZoneID` ES el
//  nombre de zona ⇒ el record se descarta antes de llegar. `applyRemoteRecord` tiene dos call-sites y los dos
//  van detrás de ese guard. La ÚNICA vía que quedaba es el **fail-abierto** de `backendGroupZoneNames` (su
//  `catch` devuelve `[]`), y es justo lo que `.skipBackendZone` cierra desde dentro.
//

import Foundation

nonisolated enum CloudKitGroupMetaApplyLogic {

    /// Qué hacer con el record.
    enum Resolution: Equatable {
        /// Alguna fila de la zona es del canal BACKEND ⇒ su verdad vive en el servidor y el record CloudKit
        /// no se aplica. Es defensa en profundidad del guard G6-3, que ya quiere esto pero **falla ABIERTO**
        /// (`backendGroupZoneNames` devuelve `[]` si su fetch lanza, y entonces pasa TODO).
        case skipBackendZone
        /// Actualizar la fila CANÓNICA de la zona (la más antigua). El caso normal.
        case updateCanonicalZoneRow
        /// La zona no tiene filas pero sí hay una con este `id`: es la fila local cuya zona todavía no
        /// cuadra. Actualizarla la CONVERGE — `CKRecordTranslator.update` le escribe el `cloudKitZoneID` del
        /// record.
        case updateRowMatchingID
        /// Zona vacía y ningún `id` que case ⇒ el grupo llega por primera vez a este device.
        case insert
    }

    /// - Parameters:
    ///   - zoneRowsAreBackend: `isBackendGroup` de **todas** las filas cuyo `cloudKitZoneID` es la zona del
    ///     record, ordenadas por `createdAt` ASC. Vacío = la zona no existe localmente.
    ///   - hasRowMatchingID: hay una fila cuyo `id` es el `modelID` del record.
    ///
    /// El orden de los casos importa y es el invariante: **el salto por canal va PRIMERO**, antes que
    /// cualquier escritura. Y el match por zona va antes que el match por `id`, que es lo que impide volver
    /// a insertar una gemela cuando la fila de la zona existe pero tiene otro `id`.
    static func resolve(zoneRowsAreBackend: [Bool], hasRowMatchingID: Bool) -> Resolution {
        if zoneRowsAreBackend.contains(true) { return .skipBackendZone }
        if !zoneRowsAreBackend.isEmpty { return .updateCanonicalZoneRow }
        return hasRowMatchingID ? .updateRowMatchingID : .insert
    }
}

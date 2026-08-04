//
//  GroupChannelFreshnessGate.swift
//  Yala
//
//  ¿Puedo afirmar que un gasto/liquidación de grupo NO EXISTE, o es que su canal todavía no lo ha traído?
//  Decisión PURA por ZONA, compartida por los DOS sitios que hoy responden esa pregunta:
//  `OrphanedBridgedTxSweeper` (que DESTRUYE cuando la respuesta es «no existe») y
//  `NewTransactionView.resolveBridgedPointer` (que ABRE Borrar/Duplicar sobre la transacción).
//
//  ── Por qué el guard anterior no bastaba ───────────────────────────────────────────────────────────────
//  `zoneIsSettled` exigía un `SplitGroup` local con `initialMemberImportStartedAt == nil`, y eso es un
//  marcador de PRIMER IMPORT, no una prueba de que el canal esté al día AHORA. Medido: los dos únicos
//  escritores que lo PONEN son las ramas grupo-NUEVO de `GroupsSyncClient.applyGroupMeta` (:2382) y
//  `SplitSyncManager.applyGroupMeta` (:2558) —ambas sobre una fila recién construida, aún sin insertar— y
//  los tres que lo limpian (`GroupsSyncClient` :2115, `GroupBackendMembershipService` :174,
//  `SplitSyncManager` :1315) lo dejan en `nil`. **Nada lo re-arma sobre una fila viva** ⇒ es un latch
//  monotónico de «esta fila terminó su primer import alguna vez». Una zona que el device conoce desde hace
//  semanas está «asentada» para siempre, con el canal apagado o rezagado.
//
//  El escenario que eso deja abierto, con dos teléfonos del MISMO usuario: el device B tuvo el grupo hace
//  semanas (marcador ya limpio); su canal de Grupos está parado (kill-switch remoto, sesión Yala caducada, o
//  el snapshot de remote-config ausente —`absentDefault` es `false` y el refresh es ≤ 6 h—); el device A crea
//  un gasto y lo puentea; esa `TransactionItem` SÍ llega a B, porque el store personal es
//  `cloudKitDatabase: .private` y los dos canales son INDEPENDIENTES. B arranca, ve punteros que no resuelven
//  en una zona «asentada», borra las virtuales y suelta las de cuenta real — y esas dos mutaciones se exportan
//  por el espejo personal, así que **el device A, que sí tiene el gasto, pierde su transacción**. Cuando el
//  gasto por fin baja a B, `bridgeExpense` ya no encuentra `existingRealTx` y crea un draft Caso A: aprobarlo
//  DUPLICA el gasto.
//
//  ── La evidencia que sí sirve, y por qué es la misma pregunta en los dos canales ───────────────────────
//  «El canal ha AGOTADO su entrega y esta zona estaba en su alcance», leído en el instante de decidir:
//
//  * **Canal backend** — `GroupsSyncClient.lastPullCycleCompleted`, que solo se enciende cuando
//    `pullUntilExhausted` devuelve `.completed`, y eso exige una página con **0 deltas** (el `limit` del
//    gateway es POR GRUPO, así que el atajo `deltas.count < limit` del canal personal no vale). Más el
//    `group_id` de la zona presente en `GroupSyncCursor.groupCursorsJSON`, que el server manda **aunque no
//    haya deltas** ⇒ tras un pull completo, todo grupo del alcance del usuario tiene entrada. El `group_id`
//    ES el `cloudKitZoneID` de la fila (`applyGroupMeta` :2361 lo pisa con él; `GroupBackendMembershipService`
//    :132 manda ese mismo string al crear), así que el mapa es indexable por zona sin ninguna derivación.
//  * **Canal CloudKit** — `SplitSyncManager.enginesWithCompletedFetchCycle`, los engines que cerraron ≥1
//    ciclo de fetch ENTERO en esta sesión (`didFetchChanges`, :1201). **Es el equivalente exacto**: un ciclo
//    entero de una base de datos enumera todas sus zonas, igual que un pull agotado enumera todos los grupos
//    del alcance. Y se limpia en `resetLocalGroupsSyncState` (:1563) por la misma razón por la que el pull
//    reinicia: ahí los change tokens se invalidan y «ya completó un ciclo» deja de decir nada del corpus que
//    viene. Más el testigo NEGATIVO por zona `zonesWithFailedFetchThisSession` (:174) — negativo a propósito,
//    porque una zona SIN cambios no emite `didFetchRecordZoneChanges` y exigir un set positivo por zona
//    deadlockearía.
//
//  **Por qué AMBOS engines y no el que sirve a la zona.** Un grupo CloudKit propio vive en la base privada y
//  uno al que me uní en la compartida, y lo que distingue una de otra es `SplitGroup.isOwner` — un predicado
//  POR FILA. Con un `SplitGroup` duplicado (estado documentado, con servicio de dedup propio) leer la fila
//  equivocada CONCEDERÍA evidencia falsa, que es la dirección que destruye. Exigir los dos engines no puede
//  equivocarse y su coste —no barrer si uno de los dos no cierra ciclo— es reversible y OBSERVABLE
//  (`MetricsCanary.bridgedTxOrphanSweepDeferred`). Es la misma asimetría del resto de esta familia: bloquear
//  de más deja una limpieza sin hacer, bloquear de menos borra dinero.
//
//  ── FALLA CERRADO ─────────────────────────────────────────────────────────────────────────────────────
//  Todo campo de `ZoneEvidence` es un `Bool` cuyo valor «no sé» es el que NIEGA. Sin evidencia no se toca
//  nada y se reintenta en el próximo arranque: perder una limpieza es reversible, destruir una transacción
//  no. Por eso `Verdict` no es un `Bool` — el motivo del bloqueo es lo que se emite al canario, y sin él un
//  gate clavado sería indistinguible de «no había huérfanas».
//

import Foundation

enum GroupChannelFreshnessGate {

    /// Estado observable de UNA zona de grupo en el instante de decidir. Lo construye
    /// `GroupChannelFreshness` leyendo el store y los dos canales; aquí no hay ni `ModelContext` ni red.
    struct ZoneEvidence: Equatable {

        /// La zona tiene ≥1 `SplitGroup` local y **NINGUNA** de sus filas está en su primer import
        /// (`initialMemberImportStartedAt == nil` en todas).
        ///
        /// Es el guard anterior, conservado —cubre el device recién instalado cuyo import personal se asienta
        /// ANTES del pull de Grupos, donde TODO el corpus puenteado parece huérfano— y **endurecido a
        /// ALL-row**: antes bastaba con que UNA fila de la zona estuviera asentada, y en una zona con
        /// duplicado eso deja pasar el caso en que la otra sigue trayendo su contenido. Mismo criterio de
        /// cuantificador que `GroupZoneCacheGate.belongsToBackendChannel`, con el signo que restringe.
        let zoneHasSettledGroup: Bool

        /// ALGUNA fila de la zona pertenece al canal backend (ANY-row, vía
        /// `GroupBackendIdentityLogic.belongsToBackendChannel`). Decide QUÉ canal tiene que dar la evidencia:
        /// con una fila backend en la zona, sus gastos bajan por el pull —el guard G6-3 descarta los records
        /// CloudKit de esa zona— así que preguntarle a CloudKit no diría nada.
        let belongsToBackendChannel: Bool

        /// El canal backend agotó su última entrega (`GroupsSyncClient.lastPullCycleCompleted`).
        let backendPullCompleted: Bool

        /// El cursor del pull lista el `group_id` de esta zona.
        let backendCursorListsZone: Bool

        /// **AMBOS** engines de CloudKit cerraron ≥1 ciclo de fetch ENTERO en esta sesión.
        let cloudKitBothEnginesCompletedFetchCycle: Bool

        /// El último `didFetchRecordZoneChanges` de esta zona llegó CON error y aún no ha vuelto a cerrar
        /// limpio: su contenido no bajó. Se auto-sana, así que un transitorio no deja el gate clavado.
        let cloudKitZoneFetchFailedThisSession: Bool
    }

    /// Por qué se concede o se niega. El motivo viaja al canario: un gate clavado tiene que ser
    /// distinguible de «no había nada que barrer».
    enum Verdict: Equatable, Sendable {
        /// El canal de esta zona agotó su entrega y la zona estaba en su alcance ⇒ «no está» significa
        /// «no existe».
        case fresh
        /// Sin `SplitGroup` local de la zona, o alguna de sus filas sigue en su primer import.
        case noSettledGroup
        /// Zona del canal backend y el pull no ha agotado su entrega (canal apagado, sesión caducada,
        /// snapshot de remote-config ausente, o simplemente todavía en vuelo).
        case backendChannelIdle
        /// El pull agotó su entrega pero el cursor NO lista esta zona ⇒ el servidor no la enumera para este
        /// usuario. No es evidencia de que sus gastos no existan: es evidencia de que este canal no habla de
        /// ella.
        case backendZoneOutOfScope
        /// Zona de CloudKit y alguno de los dos engines no ha cerrado un ciclo entero en esta sesión.
        case cloudKitChannelIdle
        /// El último fetch de esta zona concreta falló.
        case cloudKitZoneFetchFailed

        var isFresh: Bool { self == .fresh }
    }

    /// Decisión pura. El orden importa: primero el guard anterior (que cubre el device recién instalado),
    /// después el canal que corresponda.
    static func evaluate(_ e: ZoneEvidence) -> Verdict {
        guard e.zoneHasSettledGroup else { return .noSettledGroup }
        if e.belongsToBackendChannel {
            guard e.backendPullCompleted else { return .backendChannelIdle }
            guard e.backendCursorListsZone else { return .backendZoneOutOfScope }
            return .fresh
        }
        guard !e.cloudKitZoneFetchFailedThisSession else { return .cloudKitZoneFetchFailed }
        guard e.cloudKitBothEnginesCompletedFetchCycle else { return .cloudKitChannelIdle }
        return .fresh
    }

    /// Azúcar para los call-sites que solo necesitan el sí/no.
    static func isFresh(_ e: ZoneEvidence) -> Bool { evaluate(e).isFresh }
}

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
//  ── La evidencia que sí sirve ──────────────────────────────────────────────────────────────────────────
//  «El canal ha AGOTADO su entrega y esta zona estaba en su alcance», leído en el instante de decidir:
//  `GroupsSyncClient.lastPullCycleCompleted`, que solo se enciende cuando `pullUntilExhausted` devuelve
//  `.completed`, y eso exige una página con **0 deltas** (el `limit` del gateway es POR GRUPO, así que el
//  atajo `deltas.count < limit` del canal personal no vale). Más el `group_id` de la zona presente en
//  `GroupSyncCursor.groupCursorsJSON`, que el server manda **aunque no haya deltas** ⇒ tras un pull completo,
//  todo grupo del alcance del usuario tiene entrada. El `group_id` ES el `cloudKitZoneID` de la fila
//  (`applyGroupMeta` lo pisa con él; `GroupBackendMembershipService` manda ese mismo string al crear), así
//  que el mapa es indexable por zona sin ninguna derivación.
//
//  ── La zona SIN canal, y por qué su veredicto se INVIRTIÓ al borrar el transporte (Fase 3, commit 1) ────
//  Mientras existió el transporte CloudKit, una zona no-backend tenía su propia evidencia —los dos engines
//  con ≥1 ciclo de fetch cerrado, más un testigo negativo por zona— y sin ella se negaba, porque «no está»
//  podía significar «todavía no ha bajado». **Borrado el transporte, esa segunda lectura deja de existir:
//  una zona a la que ningún canal sirve no puede recibir nada nunca más, así que «no está» significa «no
//  existe» y el veredicto correcto es el que CONCEDE.**
//
//  Conceder aquí no reabre la dirección destructiva del inventario A2·(ii), y la razón es de ORDEN, no de
//  grado: desde A2·(iii) (`0ca523a6`) el barrido saca las zonas no-backend de su conjunto de CANDIDATAS
//  —`OrphanedBridgedTxSweeper.zoneIsSweepable` abre con `guard status.belongsToBackendChannel`— y ese guard
//  corre ANTES de mirar el veredicto. ⇒ nada automático toca una zona legacy, dijera lo que dijera este
//  gate; lo único que el veredicto gobierna en ellas es el editor, que no destruye por su cuenta: le
//  devuelve al usuario Borrar y Duplicar sobre una transacción cuyo gasto ya no puede llegar. Negarlo
//  dejaría dinero fantasma **atrapado** —ni editable ni borrable, con un banner que ofrece abrir un grupo
//  vacío—, que es el bug de `qa_groups-tx-fantasma-al-borrar-gasto-de-grupo` por la puerta de atrás.
//  **Ese guard del barrido pasa aquí de optimización a load-bearing**: quitarlo, con este veredicto puesto,
//  sí destruiría. Lo pinnean `sweep_cloudKitZone_isNotACandidate` y el source-scan
//  `sweeperCanary_isEmittedBeforeTheEmptyOutcomeReturn`, los dos en `GroupRemoteDeletionUnbridgeTests`.
//
//  **Lo que sigue cubriendo el device recién reinstalado** es el PRIMER escalón, no el brazo que se fue: ahí
//  el store de Grupos arranca literalmente vacío (`cloudKitDatabase: .none`) y una zona legacy no tiene
//  `SplitGroup` que la repueble —el pull backend no la enumera— ⇒ `zoneHasSettledGroup` es `false` ⇒
//  `.noSettledGroup`, y no se llega a conceder. La concesión exige una fila local asentada de esa zona, que
//  es exactamente el estado «este device ya conoce el grupo y lo que tiene es todo lo que habrá».
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
        /// `GroupBackendIdentityLogic.belongsToBackendChannel`). Decide si esta zona TIENE canal: con una
        /// fila backend, su verdad vive en el servidor y hay que esperar a que el pull la agote; sin
        /// ninguna, ya no la sirve nadie y no hay nada que esperar.
        let belongsToBackendChannel: Bool

        /// El canal backend agotó su última entrega (`GroupsSyncClient.lastPullCycleCompleted`).
        let backendPullCompleted: Bool

        /// El cursor del pull lista el `group_id` de esta zona.
        let backendCursorListsZone: Bool
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

        var isFresh: Bool { self == .fresh }
    }

    /// Decisión pura. El ORDEN de los dos primeros guards es lo que sostiene el fail-closed tras la Fase 3:
    /// el escalón de la fila asentada va PRIMERO, así que una zona sin `SplitGroup` local —el device recién
    /// reinstalado— nunca alcanza la concesión de la zona sin canal.
    static func evaluate(_ e: ZoneEvidence) -> Verdict {
        guard e.zoneHasSettledGroup else { return .noSettledGroup }
        // Zona sin canal: nadie puede entregarle nada ya, así que «no está» es «no existe». Ver la cabecera
        // — esto solo gobierna al editor; el barrido las excluyó del conjunto de candidatas en A2·(iii).
        guard e.belongsToBackendChannel else { return .fresh }
        guard e.backendPullCompleted else { return .backendChannelIdle }
        guard e.backendCursorListsZone else { return .backendZoneOutOfScope }
        return .fresh
    }

    /// Azúcar para los call-sites que solo necesitan el sí/no.
    static func isFresh(_ e: ZoneEvidence) -> Bool { evaluate(e).isFresh }
}

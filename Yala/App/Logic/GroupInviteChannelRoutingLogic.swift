//
//  GroupInviteChannelRoutingLogic.swift
//  Yala
//
//  Pure-logic del enrutado de un invite link a su CANAL (backend `g`+`t` vs CKShare) cuando el
//  flag remoto puede estar stale. Fix del 2026-07-31 (dos iPhones reales, producción, con
//  `GROUPS_BACKEND_ROLLOUT_PERCENT = 100` ya desplegado): el enlace abría Yala y no ocurría NADA.
//
//  **El invariante que gobierna este fichero: se enruta por la FORMA DEL LINK, y el flag decide
//  QUÉ hacer — nunca SI se mira.** `AppBootstrapper.handleInviteLink` evaluaba
//  `extractBackendInvite` DETRÁS de `if CloudSyncFlags.groupsBackendEnabled`, y el docblock de esa
//  rama prometía que con el flag OFF el camino era «byte-idéntico al de CKShare». La promesa era
//  falsa, y de la peor manera: un link backend NO cae al `guard let shareURL else { … }` que avisa
//  al usuario, porque `InviteLinkService.extractShareURL` **lo acepta**. Su `s` es el base64URL de
//  `https://yala-app.pe/invite?g=..&t=..` (forma mínima self-referential que el AASA exige), o sea
//  una URL perfectamente construible: `URL(string:)` no falla, y el guard host/path que sigue
//  valida el URL EXTERIOR, no el decodificado. ⇒ el invite backend entraba al canal CKShare
//  disfrazado: warm, `fetchShareMetadata` le pedía a CloudKit metadata de `yala-app.pe`; cold, se
//  PERSISTÍA en `PendingInviteStore` y `reEmitPendingInviteIfNeeded` lo reintentaba en cada
//  foreground. Cero UI en ambos.
//
//  **Y el flag OFF no es un caso raro durante un rollout**: `groupsBackendEnabled` es
//  `compilado && CloudRemoteFlags.groupsBackendEnabled`, y el snapshot del remote-config se
//  refresca como mucho cada 6 h (`RemoteFlagDecisionLogic.refreshMinInterval`) con `absentDefault`
//  = false en producción. Cualquier invitado cuyo device guardó la config antes de que el percent
//  subiera queda fuera durante horas. **Recibir un link backend es EVIDENCIA de que el canal está
//  encendido** — de ahí `.refreshFlagsThenRetry`.
//
//  Sin SwiftData/red/UI — tabla completa en GroupInviteChannelRoutingLogicTests, que además pinnea
//  el hallazgo de arriba (`extractShareURL` acepta un link backend) para que el ORDEN de evaluación
//  del call-site no pueda volver a invertirse en silencio.
//

import Foundation

nonisolated enum GroupInviteChannelRoutingLogic {

    /// Destino del link. `didRefreshFlags` distingue el primer paso del segundo dentro del MISMO
    /// tap: sin ese discriminador, `.refreshFlagsThenRetry` se re-emitiría a sí mismo en bucle.
    enum Route: Equatable {
        /// Canal nuevo: `GroupBackendInviteEntryHandler` (warm) o persist + reconciler (cold).
        case backend
        /// Canal viejo: `extractShareURL` + `processInvite`. Ruta de TODO link no-backend.
        case ckShare
        /// Link backend con el flag OFF y el snapshot sin re-consultar: forzar `GET /config` y
        /// volver a preguntar. El intent se persiste ANTES del await (ver `handleBackendInvite`).
        case refreshFlagsThenRetry
        /// Link backend, flag OFF y el server ya consultado: kill-switch bajado a propósito, o un
        /// percent que de verdad excluye a este device. Toca DECÍRSELO al usuario — un enlace que
        /// abre la app y no hace nada es el peor resultado posible: el invitado no sabe si falló el
        /// enlace, la app o él. El intent queda persistido: si el owner sube el percent, el
        /// reconciler lo completa (su rama `.skipFlagOff` conserva, TTL 7 días).
        case backendUnavailable
    }

    /// - Parameters:
    ///   - isBackendLink: el link parsea como backend (`g`+`t`, directos o dentro de `s`). Se
    ///     computa con `InviteLinkService.extractBackendInvite` SIN gatear por el flag.
    ///   - flagEnabled: `CloudSyncFlags.groupsBackendEnabled` (compuesto compilado && remoto).
    ///   - didRefreshFlags: ya se forzó el `GET /config` en este mismo tap.
    static func route(
        isBackendLink: Bool,
        flagEnabled: Bool,
        didRefreshFlags: Bool
    ) -> Route {
        // Un link NO-backend va al canal viejo SIEMPRE, con el flag como esté. Es lo que mantiene
        // el camino CKShare literalmente intacto para los grupos que no migraron.
        guard isBackendLink else { return .ckShare }
        if flagEnabled { return .backend }
        return didRefreshFlags ? .backendUnavailable : .refreshFlagsThenRetry
    }
}

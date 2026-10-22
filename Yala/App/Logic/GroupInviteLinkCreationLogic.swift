//
//  GroupInviteLinkCreationLogic.swift
//  Yala
//
//  Pure-logic de POR QUÉ el botón «compartir enlace» no puede emitir uno. Existe porque las dos
//  superficies que acuñan invitación —`GroupMembersView.createShareLink` y
//  `GroupDetailViewModel.createShareLink`— gateaban por el MISMO `if groupsBackendEnabled &&
//  isBackendGroup` y su rama negativa mostraba UN solo mensaje: `groups.errors.inviteFailed`, que
//  dice «revisa tu conexión».
//
//  **El problema medido (ticket `invite-link-five-causes-one-message`, pieza 4): ese `else` cubre
//  DOS causas de naturaleza opuesta y ninguna de las dos es la conexión.**
//
//   - **Grupo de la era CloudKit** (`!isBackendGroup`) → PERMANENTE. No hay ninguna vía por la que
//     ese grupo emita un enlace: `migrate_group` está revocada y sin endpoint en el cliente
//     (medido 2026-09-05). «Revisa tu conexión e inténtalo de nuevo» manda al admin a reintentar
//     algo que no va a funcionar NUNCA — el mismo modo de fallo que la pieza 1 arregló del lado del
//     invitado («pídele al admin que regenere uno» para un grupo borrado).
//   - **Canal apagado** (`!backendEnabled`: kill remoto, o snapshot de remote-config ausente) →
//     TRANSITORIO. Aquí «vuelve a intentarlo» sí es cierto, pero no por la conexión del admin: es
//     el canal el que está abajo, y decirle que revise su WiFi lo manda a diagnosticar su router.
//
//  El tercer caso —la red de verdad— no pasa por aquí: es el `catch` del RPC, y ahí
//  `inviteFailed` es exactamente el copy correcto. Por eso esta función devuelve `nil` cuando no
//  hay bloqueo previo: el fallo que quede es del intento real.
//
//  Sin SwiftData/red/UI — tabla completa en `GroupInviteLinkCreationLogicTests`.
//

import Foundation

nonisolated enum GroupInviteLinkCreationLogic {

    /// Motivo por el que ni siquiera se intenta acuñar el enlace.
    enum Blocker: Equatable {
        /// Grupo de la era CloudKit: no admite enlaces por ninguna vía, y no la admitirá.
        /// Consejo honesto = crear un grupo nuevo, que es la única acción que sí funciona.
        case legacyGroup
        /// El canal de grupos está apagado ahora mismo. Reintentar más tarde es correcto.
        case channelOff
    }

    /// - Parameters:
    ///   - backendEnabled: `CloudSyncFlags.groupsBackendEnabled` (compilado && remoto).
    ///   - isBackendGroup: `SplitGroup.isBackendGroup` — la zona vive en el canal nuevo.
    /// - Returns: el bloqueo, o `nil` si se puede intentar el RPC.
    ///
    /// **`legacyGroup` gana cuando concurren las dos**, y no es arbitrario: si el canal vuelve a
    /// encenderse mañana, ese grupo seguirá sin poder emitir enlace. Prometer «inténtalo más tarde»
    /// a quien tiene un grupo legacy sería el mismo consejo imposible por otra puerta.
    static func blocker(backendEnabled: Bool, isBackendGroup: Bool) -> Blocker? {
        guard !(backendEnabled && isBackendGroup) else { return nil }
        return isBackendGroup ? .channelOff : .legacyGroup
    }
}

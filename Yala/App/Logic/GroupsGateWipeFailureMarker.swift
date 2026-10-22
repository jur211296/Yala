//
//  GroupsGateWipeFailureMarker.swift
//  Yala
//
//  **«La vuelta al neutro que armó la puerta de Grupos no pudo borrar este teléfono.»** Testigo one-shot del ticket
//  `sign-out-wipe-abort-loops-the-groups-gate`.
//
//  El bucle que cierra: la puerta arma el borrado del arranque y persiste su destino; el arranque aborta en el guard S3
//  (un archivo del store no se deja borrar) y, con el modo en `.icloud`, DESARMA. Los datos y el espejo siguen, así que
//  el arranque retoma la puerta, la puerta vuelve a medir lo mismo, vuelve a armar y pide reabrir Yala otra vez. Y cada
//  vuelta cancela las notificaciones locales y vacía el widget (`clearLocalSurfacesForArmedWipe`).
//
//  Sin esta marca no hay forma de distinguir «este arranque viene de un aborto» de «este arranque es el primero»: el arm
//  se desarmó y los datos siguen, que es exactamente el estado de partida.
//
//  **Quién la escribe:** `SwiftDataConfiguration.performSignOutWipeIfArmed`, en el abort S3 que desarma, y solo si hay un
//  destino pendiente de la puerta (`.groupsOrganizer` o `.groupsInvite`). Un cierre de Ajustes que aborta no la pone:
//  la persona sigue en la app, y una marca sin lector acabaría leyéndola una puerta que no la armó.
//  **Quién la lee:** la puerta, antes de medir la celda de cierre — con ella puesta enseña «No pudimos preparar este
//  teléfono» y no arma nada.
//  **Quién la retira:** la salida de esa pantalla (la persona ya lo leyó; el siguiente intento es suyo), la puerta cuando
//  deja pasar (ya no hay nada que borrar), y un borrado que sí completa (el hecho dejó de ser verdad).
//
//  `cloudSync.*` a propósito, como `GroupsSignOutBannerMarker`: el barrido de preferencias no la toca, así que solo se
//  va por los tres caminos de arriba.
//

import Foundation

nonisolated enum GroupsGateWipeFailureMarker {

    static let key = "cloudSync.groupsGate.wipeCouldNotDelete"

    static func mark(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }

    static func isPending(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    /// ¿Armó este borrado la puerta de Grupos? Lo dice su destino pendiente: solo la puerta los persiste
    /// (`onGroupsGateNeutralReturnArmed` en `ContentView`), y los persiste DESPUÉS del arm.
    static func armedByTheGroupsGate(pendingDestination: WelcomeMirrorRelaunchLogic.Destination?) -> Bool {
        // Exhaustivo y sin `default`: un destino nuevo tiene que decidir aquí si lo escribe la puerta.
        switch pendingDestination {
        case .groupsOrganizer, .groupsInvite:
            return true
        case .privateOnboarding, .restoreICloud, .inviteRecovery, .cloudAccount, .cloudSignIn,
             .fullActivationPrivate, .fullActivationRestore, nil:
            return false
        }
    }
}

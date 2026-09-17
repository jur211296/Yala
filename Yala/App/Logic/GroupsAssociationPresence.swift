//
//  GroupsAssociationPresence.swift
//  Yala
//
//  **La lectura VIVA de «qué pinta la sección Grupos de ¿Dónde viven tus datos?», en un solo sitio.**
//
//  La tabla que decide es pura y vive en `GroupsAssociationLogic`; lo que hay aquí es el cableado a los
//  servicios que la alimentan. Están separados a propósito —la tabla se fija sin cargar nada— y este
//  fichero existe porque ese cableado tiene ahora DOS consumidores:
//
//   1. `GroupsAssociationSection`, que pinta la sección.
//   2. `ProfileView`, que decide si la FILA que lleva hasta ella se ve (`StorageRowGateLogic.isVisible`).
//
//  ## Por qué no vale que cada uno lea lo suyo
//
//  Lo cazó la review adversarial del 2026-09-11, con dos lentes independientes dando la misma celda. El
//  primer intento de arreglo pasaba al gate `GroupsAccountAssociation.shared.hasAssociation` —el registro
//  persistido— mientras la sección ofrece el botón «Desasociar» por un criterio DISTINTO: en sesión
//  privada le basta una **sesión de grupos viva**, sin mirar el registro
//  (`GroupsAssociationLogic.sectionState`, rama `.privateSession`). Los dos predicados divergen en dos
//  celdas reales, y las dos son el bug del ticket otra vez:
//
//   · **Sesión viva SIN registro** ⇒ la sección ofrece soltar la cuenta y la fila seguía oculta bajo el
//     kill. Se llega por el «empiezo de cero» del Welcome —que borra el espejo local y sella el dominio;
//     desde el 2026-09-17 además RETIRA la sesión en la nube (`CloudSessionRetirement`), pero el retiro
//     es un `Task` y un kill lo deja para el arranque siguiente, así que la celda sigue siendo
//     alcanzable— y por cualquier sesión anterior al paso 10 cuyo
//     backfill no llegara a escribir. El gesto sí funciona ahí: `CloudSessionSignOut.detachGroupsAccount`
//     resuelve la cuenta con `associatedSub ?? CloudAuthService.currentUserID`.
//   · **Registro SIN sesión privada** (`.cloudGroupsOnly`, `.fresh`) ⇒ la sección no aplica y la fila se
//     abría a una pantalla con el estado y nada más. El registro viaja por el iCloud-KV del **Apple ID**,
//     así que el iPad solo-grupos del mismo Apple ID lo lee aunque nunca haya asociado nada aquí.
//
//  ⇒ **El término que abre la fila no es «hay un registro», es «hay una cuenta que esta pantalla pueda
//  soltar»**, y esa pregunta ya la contesta `GroupsAssociationLogic.offersDetach` sobre el MISMO estado
//  que pinta la sección. Leerlo dos veces es cómo se vuelven a separar.
//
//  ## Qué NO hace
//
//  No decide nada: no hay ninguna tabla aquí. Si algo tiene que elegir entre estados, va a
//  `GroupsAssociationLogic`, que se fija sin simulador.
//

import Foundation

/// Resuelve el estado de la sección con los servicios vivos. `@MainActor` porque `GroupsAccountAssociation`
/// y `CloudAuthService` lo son; los dos call-sites son bodies de SwiftUI, que ya corren ahí.
@MainActor
enum GroupsAssociationPresence {

    /// El estado que pinta la sección.
    ///
    /// - Parameter hasCompletedOnboarding: `AppPreferences.hasCompletedOnboarding`. Entra por parámetro y
    ///   no se lee aquí porque es el único de los tres ejes que la vista ya tiene inyectado y observa: leerlo
    ///   de `UserDefaults` por dentro rompería la reactividad del call-site sin avisar.
    static func sectionState(hasCompletedOnboarding: Bool) -> GroupsAssociationLogic.SectionState {
        GroupsAssociationLogic.sectionState(
            deviceState: CloudIdentityRoutingLogic.deviceState(
                hasCompletedOnboarding: hasCompletedOnboarding,
                storageMode: StorageModePersistence.read(),
                hasPrivateSession: PrivateSessionMark.hasPrivateSession()),
            hasPersistedAssociation: GroupsAccountAssociation.shared.hasAssociation,
            hasLiveGroupsSession: CloudAuthService.shared.hasSession)
    }

    /// **¿Hay una cuenta de grupos que esta pantalla pueda soltar?** Es el término que abre la fila de
    /// Ajustes cuando el kill-switch de la nube está bajado: mientras sea cierto, existe un gesto detrás
    /// de la fila, y esconderla deja a esa persona con la cuenta puesta y sin ninguna superficie.
    ///
    /// Es la MISMA pregunta que decide si el botón «Desasociar» se dibuja, y se contesta con la misma
    /// lectura — ver la cabecera.
    static func offersDetach(hasCompletedOnboarding: Bool) -> Bool {
        GroupsAssociationLogic.offersDetach(sectionState(hasCompletedOnboarding: hasCompletedOnboarding))
    }
}

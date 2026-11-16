//
//  WelcomeRestoreRelaunchLogic.swift
//  Yala
//
//  UX 2.2 · L6-2 (decisión de Jürgen: opción B). «Restaurar desde iCloud» en un teléfono SIN iCloud pedía reabrir
//  Yala y, al volver, la primera pantalla era «Activa iCloud para continuar». Lo que decide si se puede restaurar
//  es si hay iCloud, y eso se sabe sin reiniciar nada.
//
//  Dos preguntas, y cada una en su sitio:
//
//  · **En el Welcome, al elegir «Restaurar»** (`skipsRelaunch`): sin iCloud no se relanza; se entra a
//    Restaurar en este mismo proceso, que enseña «Activa iCloud» en el acto. Con iCloud, el portal de siempre
//    (`WelcomeMirrorRelaunchLogic.shouldRelaunch`) decide igual que antes.
//  · **En Restaurar, al buscar** (`needsRelaunchToSearch`): si la persona encendió iCloud mientras tanto y este
//    proceso montó el store neutro, buscar no traería nada —el espejo no está—. Ahí se pide reabrir, con el mismo
//    destino durable que habría escrito el Welcome.
//
//  Lo que NO cambia: con iCloud, el orden es el de siempre (relanzar y luego buscar). La pregunta «¿hay iCloud?» es
//  la MISMA en el Welcome y en Restaurar, para que uno no diga «sin iCloud» y el otro «con iCloud» a la vez.
//
//  **Desde el 2026-11-05 (card 6a12, ticket `restore-with-icloud-drive-off-mounts-without-mirror`) esa pregunta es la
//  cuenta de CloudKit, no el token de iCloud Drive.** Con la sesión de iCloud abierta y Drive apagado,
//  `ubiquityIdentityToken` es `nil` y CloudKit funciona: Restaurar decía «Activa iCloud» a quien tenía sus datos ahí.
//  Ahora es `iCloudSyncService.hasICloudAccount` (token, o CloudKit `.available`) y, si CloudKit aún no contestó,
//  Restaurar le pregunta antes de decidir (`accountCheck`). La tabla de montaje NO cambia, y está medido: tras reabrir,
//  el chooser ya está marcado, el neutro caduca y con Drive apagado monta `.localNoMirror`, que adjunta el espejo con
//  el contenedor nombrado (card n5zw). Sin cuenta de iCloud sigue saliendo «Activa iCloud».
//

import CloudKit

nonisolated enum WelcomeRestoreRelaunchLogic {

    /// ¿Se sale del Welcome SIN relanzar aunque el portal lo pediría? Solo para Restaurar y solo sin iCloud:
    /// Restaurar dirá «Activa iCloud» sin que la persona tenga que cerrar la app para enterarse. El resto de
    /// destinos que necesitan el espejo (el onboarding privado, recuperar una invitación) no cambian: no le
    /// preguntan nada a iCloud antes de seguir.
    static func skipsRelaunch(destination: WelcomeMirrorRelaunchLogic.Destination, iCloudAccountPresent: Bool) -> Bool {
        destination == .restoreICloud && !iCloudAccountPresent
    }

    /// ¿Hay que reabrir antes de buscar? Con iCloud ya disponible y el store de este proceso montado neutro —el
    /// caso que deja `skipsRelaunch` cuando la persona enciende iCloud después—. Es el mismo
    /// predicado del portal del Welcome para el destino `.restoreICloud`, para que los dos sitios no diverjan.
    static func needsRelaunchToSearch(
        iCloudAccountPresent: Bool,
        mountedDecision: SwiftDataConfiguration.PersonalStoreDecision
    ) -> Bool {
        iCloudAccountPresent
            && WelcomeMirrorRelaunchLogic.shouldRelaunch(destination: .restoreICloud, mountedDecision: mountedDecision)
    }

    /// Qué sabe Restaurar de la cuenta de iCloud al empezar a buscar.
    enum AccountCheck: Equatable {
        /// Hay cuenta: el token de Drive, o CloudKit dijo `.available`.
        case present
        /// No hay cuenta, o CloudKit no la confirmó tras preguntarle: «Activa iCloud».
        case absent
        /// Sin token y CloudKit sin contestar todavía en este proceso: se le pregunta antes de decir «Activa iCloud».
        case askCloudKit
    }

    /// **Una sola pregunta a CloudKit por búsqueda.** Sin token y sin respuesta de CloudKit, decir «Activa iCloud» sería
    /// adivinar en contra de quien tiene Drive apagado; preguntar sin tope colgaría la pantalla si CloudKit no contesta
    /// (los hosts de test no preguntan nunca). Tras preguntar, lo que no sea `.available` es «sin cuenta», como antes.
    static func accountCheck(tokenPresent: Bool, cloudKitStatus: CKAccountStatus?, alreadyAsked: Bool) -> AccountCheck {
        if ICloudAccountWitness.hasAccount(tokenPresent: tokenPresent, cloudKitStatus: cloudKitStatus) { return .present }
        if cloudKitStatus == nil && !alreadyAsked { return .askCloudKit }
        return .absent
    }
}

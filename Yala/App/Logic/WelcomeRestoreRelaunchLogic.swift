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
//  `iCloudSyncService.isAccountAvailable` (`FileManager.ubiquityIdentityToken`), la misma que usa Restaurar para
//  su estado `.iCloudDisabled`: así el Welcome no puede decir «sin iCloud» y Restaurar «con iCloud» a la vez.
//

nonisolated enum WelcomeRestoreRelaunchLogic {

    /// ¿Se sale del Welcome SIN relanzar aunque el portal lo pediría? Solo para Restaurar y solo sin iCloud:
    /// Restaurar dirá «Activa iCloud» sin que la persona tenga que cerrar la app para enterarse. El resto de
    /// destinos que necesitan el espejo (el onboarding privado, recuperar una invitación) no cambian: no le
    /// preguntan nada a iCloud antes de seguir.
    static func skipsRelaunch(destination: WelcomeMirrorRelaunchLogic.Destination, iCloudAvailable: Bool) -> Bool {
        destination == .restoreICloud && !iCloudAvailable
    }

    /// ¿Hay que reabrir antes de buscar? Con iCloud ya disponible y el store de este proceso montado neutro —el
    /// caso que deja `skipsRelaunch` cuando la persona enciende iCloud después—. Es el mismo
    /// predicado del portal del Welcome para el destino `.restoreICloud`, para que los dos sitios no diverjan.
    static func needsRelaunchToSearch(
        iCloudAvailable: Bool,
        mountedDecision: SwiftDataConfiguration.PersonalStoreDecision
    ) -> Bool {
        iCloudAvailable
            && WelcomeMirrorRelaunchLogic.shouldRelaunch(destination: .restoreICloud, mountedDecision: mountedDecision)
    }
}

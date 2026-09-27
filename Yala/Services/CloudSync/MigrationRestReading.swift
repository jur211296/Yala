//
//  MigrationRestReading.swift
//  Yala
//
//  Los seis insumos con los que se decide si el paso de los datos entre iCloud y la nube está en REPOSO
//  (`AppleIDChangeCloseLogic.migrationAtRest`), leídos en un solo sitio.
//
//  POR QUÉ EXISTE. Hasta el ticket `private-sign-out-proceeds-with-a-migration-in-flight` (2026-09-27) esa lectura
//  vivía dentro de `AppBootstrapper`, y su único lector era la oferta automática del cambio de Apple ID. El cierre de
//  la sesión privada necesita la MISMA pregunta —«¿puedo borrar lo local ahora?»— y dos copias de las seis lecturas
//  divergen en cuanto una aprende una fuente nueva: es como el guard de la oferta llegó a leer solo el controller y a
//  conceder sin él. Aquí hay una sola lectura; el predicado sigue siendo uno.
//

import Foundation

nonisolated struct MigrationRestReading: Equatable {
    /// `uiState` del controller, o `nil` si no existe (sin backend configurado, antes del paso 14.6 del arranque, en
    /// el swap de persona). `nil` no concede nada: solo quita una fuente.
    let controllerState: CloudMigrationUIState?
    /// El controller está conduciendo algo. Su `uiState` solo se repinta en `refresh()`.
    let controllerIsWorking: Bool
    /// La fase del journal, o que no se pudo leer.
    let journalRead: JournaledPhaseRead
    let persistedStorageMode: StorageMode
    let mirrorOffArmed: Bool
    let mountedDecision: SwiftDataConfiguration.PersonalStoreDecision
}

extension MigrationRestReading {
    /// La lectura de producción. La comparten la oferta del cambio de Apple ID (`AppBootstrapper`) y el cierre de la
    /// sesión privada (`CloudSessionSignOut`).
    @MainActor static var live: MigrationRestReading {
        MigrationRestReading(
            controllerState: CloudMigrationController.shared?.uiState,
            controllerIsWorking: CloudMigrationController.shared?.isWorking ?? false,
            journalRead: MigrationPhaseStore.shared.currentPhaseRead,
            persistedStorageMode: StorageModePersistence.read(),
            mirrorOffArmed: StorageModePersistence.isMirrorOffArmed(),
            mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision)
    }
}

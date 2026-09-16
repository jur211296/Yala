//
//  StorageRowGateLogic.swift
//  Yala
//
//  Pure-logic de visibilidad de la fila "Almacenamiento" de Profile (DIFERIDOS #34).
//
//  Decisión owner (2026-07-17): el kill-switch remoto `cloudModeEnabled=OFF` corta solo la
//  ENTRADA — un usuario "engaged" (ya `.cloud`, o con migración/reversa en vuelo o fallida)
//  CONSERVA la fila SIEMPRE: es su panel de gestión, resume y REVERSA (el escape ante incidente).
//  OFF + no-engaged ⇒ oculta. Sigue siendo el estado de producción HOY, pero por otra razón que antes:
//  el backend ya está configurado (D-R1 paso 1) y lo que apaga la fila es el flag remoto, porque el
//  gateway sirve `CLOUD_MODE_ROLLOUT_PERCENT = "0"`.
//
//  **Esta fila es la SEGUNDA de las dos puertas de la NUBE, y bajo el kill se cierran las dos**
//  (ratificado 2026-09-06). La primera es la card de sign-in del Welcome
//  (`WelcomeAccountChoiceLogic.visibleExistingOptions`, donde vive el residual completo). Aquí el
//  cierre no era un término propio sino una consecuencia: quien REINSTALA no puede estar `isEngaged`
//  —ese estado es local y se fue con la app—, así que `remoteEnabled || isEngaged` era falso por los
//  dos lados. Conviene saberlo antes de "arreglar" una puerta sin mirar la otra.
//
//  **Esa decisión sigue vigente y este fichero la cumple — pero desde el 2026-09-11 la cumple con un
//  término EXPLÍCITO y no de rebote.** Jürgen ratificó el 6-sep «nube en pausa para todos, también para
//  volver», y descartó entonces mantener viva esta fila bajo el kill porque tocar este gate era tocar el
//  freno de emergencia. Lo que cambió tres días después es la PREMISA, no la política: el paso 10 metió
//  detrás de esta fila la gestión de la cuenta de grupos, que va por OTRO flag y que el kill de la nube
//  no debería apagar. Así que la fila se abre por ese eje (ver abajo) y **la puerta de la nube se cierra
//  donde de verdad vive**: `offersCloudMigrationEntry`. Encargo de Jürgen del 11-sep, ticket
//  `cloud-killswitch-hides-the-only-door-to-detach-groups`.
//
//  Y lo que no se toca sigue sin tocarse: un usuario ya engaged conserva su fila y su reversa, que es el
//  escape ante incidente.
//
//  ## El tercer término: una cuenta de grupos que soltar (2026-09-11)
//
//  Desde el paso 10 esta fila dejó de hablar solo del almacenamiento PERSONAL: dentro vive la sección
//  que muestra la cuenta de la nube asociada para Grupos y la única superficie desde la que se suelta
//  (`GroupsAssociationSection`). Y Grupos va por SU propio flag (`groupsBackendRolloutPercent`), así que
//  bajar el kill de la nube dejaba a quien tuviera esa cuenta con la cuenta puesta y sin puerta para
//  soltarla. Es el mismo criterio del `isEngaged` —«un usuario ya dentro conserva su panel de gestión»—
//  aplicado al otro eje, y cubre además la variante corta: en una instalación fresca, antes del primer
//  `/config`, el `absentDefault` de producción es `false` y la fila nacería oculta.
//
//  **El término es «hay algo que soltar», no «hay un registro de asociación».** La diferencia no es de
//  matiz: la sección ofrece el botón «Desasociar» también con una sesión de grupos VIVA y sin registro
//  persistido, y con el registro a secas la fila seguía oculta para esa gente. Quien contesta la pregunta
//  —con la MISMA lectura que pinta la sección, que es lo que impide que vuelvan a separarse— es
//  `GroupsAssociationPresence.offersDetach`. El porqué entero está en su cabecera.
//
//  **El guard de arriba sigue mandando sobre este término, y es a propósito:**
//   - `isConfigured` — sin backend configurado `CloudMigrationController.shared` es `nil` y la pantalla
//     degrada al mensaje genérico SIN montar la sección de grupos: abrir ahí sería una puerta a nada.
//
//  **Y abrir la fila no es abrir la migración.** Lo mide `offersCloudMigrationEntry`, abajo: la entrada
//  personal a la nube no tiene ningún otro gate del kill-switch —ni en `StorageSettingsView` ni en
//  `CloudMigrationController`, medido el 2026-09-11—, así que sin esa segunda tabla este término habría
//  convertido «el kill corta la ENTRADA» en «el kill corta la entrada salvo si tienes grupos».
//

import Foundation

nonisolated enum StorageRowGateLogic {

    /// - Parameters:
    ///   - isConfigured: backend configurado (`CloudBackendConfig.isConfigured`).
    ///   - remoteEnabled: flag remoto `CloudRemoteFlags.cloudModeEnabled`.
    ///   - isEngaged: el usuario ya está dentro (modo persistido `.cloud` o
    ///     `CloudMigrationController.uiState` más allá de `.idle` — journal transicional,
    ///     relaunch pendiente, cloudActive, waitingForLeader o terminal de fallo).
    ///   - hasGroupsAccountToDetach: la sección de Grupos de esta pantalla tiene una cuenta que soltar
    ///     (`GroupsAssociationPresence.offersDetach`). Ver «El tercer término» en la cabecera: el criterio
    ///     es el gesto que hay detrás, no el registro persistido, y por eso el nombre dice «to detach».
    ///     Default `false` ⇒ la tabla 2⁴ anterior sigue midiendo lo mismo donde no aplica.
    static func isVisible(
        isConfigured: Bool,
        remoteEnabled: Bool,
        isEngaged: Bool,
        hasGroupsAccountToDetach: Bool = false
    ) -> Bool {
        guard isConfigured else { return false }
        return remoteEnabled || isEngaged || hasGroupsAccountToDetach
    }

    /// ¿Ofrece la pantalla la ENTRADA personal a la nube («Migrar a la nube» / «Adoptar»)?
    ///
    /// **Es el gate que antes hacía `isVisible` sin querer.** Mientras la fila solo hablaba del
    /// almacenamiento personal, ocultarla bajo el kill cerraba la migración de paso: la card no tiene
    /// ningún otro candado —`CloudRemoteFlags` no se consulta en `StorageSettingsView` ni en
    /// `CloudMigrationController`, medido el 2026-09-11—. Al abrir la fila por
    /// `hasGroupsAccountToDetach`, esa consecuencia se pierde, así que el término se escribe aquí explícito:
    /// quien entra a soltar su cuenta de grupos durante un incidente **no** encuentra abierta la puerta
    /// que el incidente cerró.
    ///
    /// La REVERSA no pasa por aquí y no debe: es el escape, vive en `.cloudActive` —que ya implica
    /// `isEngaged`— y el kill jamás la ha tocado.
    ///
    /// **Y gatea el RENDER de la card, que no es lo mismo que gatear la migración.** El flujo que arranca
    /// esa card —consent, doble confirmación, chooser, `startMigration`— no vuelve a preguntar por el
    /// flag en ningún punto, así que quien tapeó «Migrar a la nube» un segundo antes de que aterrizara el
    /// snapshot nuevo terminaba migrando con el kill ya puesto. Por eso el mismo término se re-mide en
    /// `StorageSettingsView.proceedToSignInStep`, que es el último sitio antes del punto de no retorno.
    ///
    /// **Sin App Attest tampoco se ofrece** (2026-09-16, ticket
    /// `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest`), y son las dos caras de la card:
    /// «Migrar a la nube» y «Activar la nube en este dispositivo» (decisión de Jürgen). El claim no pide attest y
    /// pasa —«Migrar» deja la cuenta creada en el servidor—, pero todo lo que sube o baja después sí lo pide: la
    /// migración se reintenta sin fin y el teléfono se queda en iCloud. La decisión es la de la puerta del alta
    /// del Welcome, `AttestSyncGate.shouldOfferCloudOnly`.
    ///
    /// **El attest cierra la ENTRADA, igual que el kill**: `isEngaged` va fuera de su término, así que quien está
    /// engaged —modo `.cloud`, o una fase que la pantalla pinta fuera de `.idle`— conserva su panel aunque su
    /// teléfono no tenga App Attest. **Un adopt pendiente no cuenta**: tras el claim `existing_stable` la fase
    /// vuelve a `notStarted` con el efecto `adoptBackendAccount` por ejecutar, la pantalla lo deriva `.idle`, y sin
    /// App Attest pierde la card mientras el reintento sigue en segundo plano.
    ///
    /// - Parameters:
    ///   - remoteEnabled: flag remoto `CloudRemoteFlags.cloudModeEnabled`.
    ///   - isEngaged: el MISMO término de `isVisible` — quien ya está dentro conserva su panel entero,
    ///     retomar incluido.
    ///   - isAttestSupported: este teléfono puede conseguir token, leído como lo lee el Welcome
    ///     (`UITestHooks.fakeAttestSupport || AppAttestClient.canObtainSessionToken`). Sin default: quien llame
    ///     tiene que decidirlo.
    static func offersCloudMigrationEntry(remoteEnabled: Bool, isEngaged: Bool, isAttestSupported: Bool) -> Bool {
        isEngaged || (remoteEnabled && AttestSyncGate.shouldOfferCloudOnly(isAttestSupported: isAttestSupported))
    }
}

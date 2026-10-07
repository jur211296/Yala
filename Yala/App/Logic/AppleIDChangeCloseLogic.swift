//
//  AppleIDChangeCloseLogic.swift
//  Yala
//
//  El predicado PURO de «el Apple ID del teléfono cambió y la sesión privada era del anterior».
//
//  POR QUÉ EXISTE, y por qué NO es «alinear el aviso que ya había». El ticket
//  (`apple-id-change-should-close-the-private-session`) daba por supuesto que
//  `AppBootstrapper.checkForICloudMismatch` ya reaccionaba al cambio de cuenta y solo había que
//  convertir su aviso en un cierre. Medido el 2026-09-14 en este árbol, no es así: el predicado que
//  gobierna ese aviso (`SwiftDataConfiguration.shouldOfferICloudRestart`) pregunta «¿monté sin espejo
//  y AHORA hay iCloud?», que es otra cosa, y **la app no guardaba ningún testigo del Apple ID con el
//  que montó** — no había con qué comparar. El aviso viejo se queda donde está: contesta otra
//  pregunta y sigue siendo correcta.
//
//  LA REGLA DEL ADR (2026-09-09 «Sesiones — dos ejes», §1). La sesión privada «vive en el dispositivo
//  y sincroniza por el iCloud privado del Apple ID del teléfono. No tiene login ni logout: salir es
//  borrar lo local y dejar el contenedor en iCloud». Si el Apple ID cambia, la sesión privada de este
//  teléfono es de una cuenta que ya no está: sus datos siguen en el iCloud del Apple ID anterior, y
//  lo local es una copia que le pertenece a otra persona. El desenlace del modelo es el cierre de
//  sesión, con su borrado por ARCHIVOS, no un aviso.
//
//  LOS CUATRO TÉRMINOS, y hacia dónde falla cada uno. Todos empujan en la misma dirección: ante la
//  duda NO se cierra. El error caro de este predicado es el `true` — borra datos de alguien.
//
//  DE DÓNDE SALE LA IDENTIDAD, y por qué NO del token de iCloud. `PrivateSessionAppleIDWitness` la
//  toma de `CKContainer.userRecordID()` del contenedor PERSONAL. El camino barato —comparar
//  `FileManager.ubiquityIdentityToken`— está descartado por la rule de área
//  (`.claude/rules/swiftdata-cloudkit.md`): ese token mide iCloud **Drive**, no CloudKit, así que con
//  Drive apagado y la sesión de iCloud viva vale `nil` mientras CloudKit funciona perfectamente.
//  Usarlo aquí convertiría «apagar iCloud Drive» en «cambiaste de Apple ID» y BORRARÍA los datos de
//  quien no cambió nada. La notificación `NSUbiquityIdentityDidChange` sí se usa, pero como
//  DISPARADOR de la comprobación, jamás como veredicto.
//
//  EL RESIDUAL, dicho entero porque no se puede cerrar. Quien cambie de Apple ID **antes** de
//  actualizar a la versión que estrena esto llega sin testigo, y el primer arranque le siembra la
//  cuenta NUEVA: su cambio ya no se detecta nunca. No hay forma de arreglarlo —nadie guardó con qué
//  cuenta se montó— y la alternativa (tratar la ausencia como sospecha) borraría los datos del parque
//  entero, que es infinitamente peor. A esa población la sigue cubriendo el cambio SIGUIENTE.
//
//  ADR 2026-09-09 §1 · ticket `apple-id-change-should-close-the-private-session`.
//

import Foundation

nonisolated enum AppleIDChangeCloseLogic {

    /// Qué hacer con la identidad que CloudKit acaba de contestar.
    enum Verdict: Equatable {
        /// La sesión privada de este teléfono es de otro Apple ID: ofrecer el cierre (con confirmación).
        case offerClose
        /// Primera lectura en este dispositivo: guardar la identidad como testigo y no hacer nada más.
        /// **Nunca cierra**: una marca ausente no es prueba de un cambio, y el parque entero llega aquí
        /// sin testigo el día que este código se estrena.
        case seedWitness
        /// Ni cierre ni testigo nuevo: la identidad coincide, o esta celda no participa.
        case ignore
    }

    /// El veredicto.
    ///
    /// - Parameters:
    ///   - confirmedPrivateSession: **la lectura ESTRICTA del eje 1** (`PrivateSessionMark`, ausente ⇒
    ///     `false`), y no la ancha. Cumple el criterio que su docblock fija para admitir un consumidor
    ///     nuevo: «hacia `true` se destruye, hacia `false` solo se conserva de más». Con la lectura
    ///     ancha, un dispositivo cuya marca aún no se ha escrito se borraría a sí mismo. **Aporta DOS
    ///     lecturas y no una** —el pre-filtro y la re-lectura tras el `await`—, así que aporta dos al
    ///     conteo que fija `PrivateSessionMarkWiringTests` (el TIPO, segunda `@Suite` de
    ///     `PrivateSessionMarkTests.swift`). El número exacto se mira allí y no aquí: esta prosa ya
    ///     caducó una vez, cuando el aviso de vaciado remoto añadió la sexta lectura el 2026-09-14.
    ///   - groupsOnlySessionArmed: el término que el ticket pide conservar explícitamente. Una sesión
    ///     solo-grupos **no tiene sesión privada que cerrar**: su store personal está vacío a
    ///     propósito y su vida vive en la cuenta de Yala, que no es del Apple ID del teléfono. Sin
    ///     este término le llegaría un aviso que le propone borrar algo que no es suyo. Va ADEMÁS del
    ///     eje 1 y no en su lugar: son dos hechos distintos y el residual del backfill (un alta
    ///     solo-grupos anterior al 2026-09-10 no tiene la marca del mount) hace que uno de los dos
    ///     pueda mentir.
    ///   - storageMode: en `.cloud` lo personal vive en la cuenta de Yala y el Apple ID del teléfono
    ///     no gobierna nada de lo personal — cambiarlo no cierra ninguna sesión. Se lee el modo
    ///     PERSISTIDO y no el mount, porque la pregunta es «¿de quién son estos datos?», que la
    ///     reversa cambia en caliente sin remontar.
    ///   - witness: la identidad guardada la última vez. `nil` = nunca se guardó ⇒ `.seedWitness`.
    ///   - currentIdentity: lo que CloudKit contesta AHORA. `nil` = no se pudo preguntar (sin red, sin
    ///     cuenta, `notAuthenticated`) ⇒ **`.ignore`**: no saber no es saber que cambió. Falla CERRADO.
    static func decide(confirmedPrivateSession: Bool,
                       groupsOnlySessionArmed: Bool,
                       storageMode: StorageMode,
                       witness: String?,
                       currentIdentity: String?) -> Verdict {
        guard participates(confirmedPrivateSession: confirmedPrivateSession,
                           groupsOnlySessionArmed: groupsOnlySessionArmed,
                           storageMode: storageMode) else { return .ignore }
        // CloudKit no contestó: no se concluye nada.
        guard let currentIdentity, !currentIdentity.isEmpty else { return .ignore }
        // Primera vez en este dispositivo: se siembra, no se cierra.
        guard let witness, !witness.isEmpty else { return .seedWitness }
        return witness == currentIdentity ? .ignore : .offerClose
    }

    /// **Los tres términos LOCALES: ¿esta celda participa siquiera?**
    ///
    /// Es la mitad del predicado que se puede contestar sin salir a la red, y por eso existe aparte: el
    /// llamador la evalúa ANTES de gastar una ida a CloudKit, que en una sesión solo-grupos o en la nube
    /// sería un viaje por arranque para contestar siempre lo mismo.
    ///
    /// **Está extraída y no duplicada, y esa es toda la gracia.** Un pre-filtro que repite la condición
    /// del criterio con su propia copia es cómo se consigue que el mutante del criterio salga VERDE: la
    /// medición nunca llega a la lógica porque el filtro ya la cortó. Aquí hay una sola fuente —`decide`
    /// la llama— así que invertir un término rompe los dos caminos, y los tests pinnean cada nivel.
    static func participates(confirmedPrivateSession: Bool,
                             groupsOnlySessionArmed: Bool,
                             storageMode: StorageMode) -> Bool {
        // 1. Sin sesión privada confirmada no hay nada que cerrar, y el testigo no describiría a nadie.
        guard confirmedPrivateSession else { return false }
        // 2. Solo-grupos nunca ve esto (criterio explícito del ticket).
        guard !groupsOnlySessionArmed else { return false }
        // 3. En la nube lo personal no es del Apple ID.
        return storageMode == .icloud
    }

    /// **¿El paso de los datos a la nube está en reposo?** Si no lo está, «ahora no es el momento» de ofrecer el cierre:
    /// cerrar a mitad de una migración o de una reversa puede borrar lo local mientras sube.
    ///
    /// **Dos fuentes y hacen falta las dos** (ticket `apple-id-change-boot-check-runs-before-the-migration-guard-can-see`).
    /// Hasta ese ticket el guard leía solo `CloudMigrationController.shared?.uiState ?? .idle`, y en el arranque corría
    /// ANTES de `configureShared`: `shared` era `nil`, el `?? .idle` concedía y la protección no existía. El controller
    /// puede faltar también después —sin backend configurado no se crea nunca, y el swap de persona lo suelta un rato—,
    /// así que además se deriva el estado desde el journal, por la MISMA derivación con la que se pinta la pantalla.
    ///
    /// - Parameters:
    ///   - controllerState: `uiState` del controller, o `nil` si no existe. `nil` no concede nada: solo quita una fuente.
    ///   - controllerIsWorking: el controller está conduciendo algo (`isWorking`). Su `uiState` solo se repinta en
    ///     `refresh()`, así que un adopt o una ida recién arrancados siguen en `.idle` mientras el runner trabaja, y el
    ///     journal de fase no los ve (el efecto del adopt se journalea con `notStarted`; consent y authenticating no se
    ///     guardan). Ocupado ⇒ no en reposo.
    ///   - journalRead: `MigrationPhaseStore.currentPhaseRead`. Ilegible ⇒ `.journalUnreadable` ⇒ **no en reposo**: no
    ///     saber en qué punto está el paso de los datos no es saber que terminó.
    ///   - persistedStorageMode / mirrorOffArmed / mountedDecision: los mismos insumos con los que `refresh()` deriva
    ///     `uiState`. El journal de fase no lleva los efectos pendientes, así que sin controller no ve el efecto del adopt
    ///     (`notStarted` + `.adoptBackendAccount`): eso solo pasa sin backend configurado, donde no hay adopt.
    ///
    /// Reposo = la derivación da `.idle`. Cualquier otro estado —progreso, relanzamiento pendiente, fallo, seguidor,
    /// nube activa, journal ilegible— no lo es. En la nube el predicado ya no participa, así que exigir `.idle` no quita
    /// ninguna oferta que fuera a salir. **`failedRollback` tampoco es reposo, y sigue sin serlo aquí**: el cierre de la
    /// sesión privada lo acepta asentado por su propio predicado (`migrationAllowsPrivateSessionClose`), y este se queda
    /// estricto porque tiene un tercer lector que borra con otra lógica —el borrado pendiente del iCloud privado del
    /// arranque (`ContentView`)—, para el que un fallo con «Reintentar» a la vista no es «la activación ya no va a
    /// ocurrir».
    static func migrationAtRest(controllerState: CloudMigrationUIState?,
                                controllerIsWorking: Bool,
                                journalRead: JournaledPhaseRead,
                                persistedStorageMode: StorageMode,
                                mirrorOffArmed: Bool,
                                mountedDecision: SwiftDataConfiguration.PersonalStoreDecision) -> Bool {
        if controllerIsWorking { return false }
        if let controllerState, controllerState != .idle { return false }
        let journalState = CloudMigrationUIStateDeriver.derive(
            storageMode: persistedStorageMode, read: journalRead,
            mirrorOffArmed: mirrorOffArmed, mountedDecision: mountedDecision)
        return journalState == .idle
    }

    /// El mismo predicado con la lectura en un solo valor (`MigrationRestReading`). Lo usan el borrado pendiente del iCloud
    /// privado del arranque (`ContentView`) y, a través de `migrationAllowsPrivateSessionClose`, los dos lectores del cierre.
    static func migrationAtRest(_ reading: MigrationRestReading) -> Bool {
        migrationAtRest(controllerState: reading.controllerState,
                        controllerIsWorking: reading.controllerIsWorking,
                        journalRead: reading.journalRead,
                        persistedStorageMode: reading.persistedStorageMode,
                        mirrorOffArmed: reading.mirrorOffArmed,
                        mountedDecision: reading.mountedDecision)
    }

    /// **¿Se puede cerrar la sesión privada sin pisar el paso de los datos a la nube?** Reposo, o una ida que FALLÓ y ya
    /// no tiene nada pendiente (ticket `apple-id-change-check-stays-off-after-a-failed-migration`, decisión A de Jürgen del
    /// 2026-10-04). Lo leen los DOS lectores del cierre y solo ellos: la oferta del cambio de Apple ID
    /// (`AppBootstrapper.migrationAtRestForAppleIDChange`) y el cierre manual (`CloudSignOutFlowLogic.migrationBlockReason`),
    /// así que se abren y se cierran a la vez. Hasta ese ticket exigían reposo, y quien no volvía a Almacenamiento a pulsar
    /// «Reintentar» se quedaba con la copia de otra cuenta en el teléfono, sin oferta y sin poder cerrar a mano.
    static func migrationAllowsPrivateSessionClose(_ reading: MigrationRestReading) -> Bool {
        migrationAtRest(reading) || migrationFailedAndSettled(reading)
    }

    /// **La ida terminó en `failedRollback` y no queda nada que un resume vaya a ejecutar.** Antes del cutover el teléfono
    /// está intacto (`MigrationWorkExecutor`, efecto `.rollback`), y el abort del paso 4 devuelve el modo a `.icloud` como
    /// PRIMER efecto; con los pendientes drenados, el teléfono está como empezó y cerrar no pisa nada. Cada término falla
    /// hacia «no se ofrece», que es como estaba:
    ///
    /// - **El controller no trabaja**, y su estado es `nil` o `.failed(.migration)`. Un `.idle` con el journal en fallo es
    ///   un `uiState` desfasado (solo se repinta en `refresh()`): no concede. Cualquier otro estado, tampoco.
    /// - **La derivación del journal da `.failed(.migration)`**, por la misma función que pinta la pantalla. Deja fuera la
    ///   vuelta fallida (`.failed(.reverse)`, que no entra en la decisión) y el relanzamiento pendiente, que gana a la fase.
    /// - **Sin efectos pendientes** (`journalHasPendingEffects`, del mismo fetch que la fase): un `.rollback` o un
    ///   `.persistICloudMode` journaleado y sin ejecutar lo ejecuta el resume del arranque; hasta entonces el fallo no está
    ///   asentado. Ilegible ya no llega aquí (la derivación da `.journalUnreadable`) y, si llegara, cuenta como pendiente.
    /// - **Modo persistido `.icloud`**: la máquina no sale a `failedRollback` con `.cloud` persistido (`MigrationRunner`), y
    ///   el término lo fija por si eso cambia. Con `.cloud`, lo local podría no estar en ningún iCloud.
    static func migrationFailedAndSettled(_ reading: MigrationRestReading) -> Bool {
        if reading.controllerIsWorking { return false }
        if let controllerState = reading.controllerState, controllerState != .failed(.migration) { return false }
        if reading.journalHasPendingEffects { return false }
        guard reading.persistedStorageMode == .icloud else { return false }
        let journalState = CloudMigrationUIStateDeriver.derive(
            storageMode: reading.persistedStorageMode, read: reading.journalRead,
            mirrorOffArmed: reading.mirrorOffArmed, mountedDecision: reading.mountedDecision)
        return journalState == .failed(.migration)
    }
}

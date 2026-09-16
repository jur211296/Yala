//
//  UITestEphemeralDefaults.swift
//  Yala
//
//  Los defaults que el modo uitest necesita puestos: EN MEMORIA y sin rastro en disco.
//
//  POR QUÉ EXISTE. El scheme `Yala Dev` usa el MISMO bundle (`…yala.dev`) para el host de los
//  XCUITest y para el de los unit tests ⇒ `UserDefaults.standard` es un único almacén compartido
//  que SOBREVIVE a la corrida. Un seam `-uitest-*` que escriba ahí no contamina "solo el test":
//  contamina al target que corre después y a cualquier ARRANQUE MANUAL de la app en ese
//  simulador. Ya pasó con `-uitest-pro` (`StoreKitManager.applyUITestProTier(_:)`, que es el
//  hermano de este fichero) y los tres seams de aquí eran sus parientes CONFIRMADOS por barrido
//  el 2026-08-05 — medidos leyendo el plist de `UserDefaults.standard` tras una corrida:
//
//    · `groupsBetaUnlocked`   — lo escribía TODO launch `-uitest` y no lo limpiaba NADIE
//                               (`removeUserPreferenceKeys` lo excluye a propósito) ⇒ el gate
//                               beta de Grupos quedaba desbloqueado para siempre en ese sim.
//    · `hasCompletedOnboarding` + `hasShownWelcomeChooser` — default del helper de launch ⇒ tras
//                               cualquier XCUITest, abrir la app a mano saltaba onboarding y
//                               Welcome Chooser.
//    · `seedCategoriesExecuted` — el traicionero, y por eso NO se arregla aquí: lo escribe código
//                               de PRODUCCIÓN (`CategorySeed`) y tiene que sobrevivir entre
//                               lanzamientos, así que no puede ser efímero. Se namespacea por
//                               store en `CategorySeedSentinel`; aquí solo vive su PURGA.
//
//  EL MECANISMO: el dominio de REGISTRO de `UserDefaults` (`register(defaults:)`). Es volátil —
//  vive en el proceso y muere con él, no toca el plist— y lo consulta la MISMA cadena de búsqueda
//  que el resto: `@AppStorage`, `bool(forKey:)` y `object(forKey:)` lo ven sin cambiar una línea
//  de los lectores. Es el equivalente para una key suelta de lo que `uiTestForcedProTier` es para
//  el singleton de StoreKit.
//
//  Y UNA PROPIEDAD DEL MECANISMO QUE HAY QUE SABER, medida y no supuesta: **el dominio de registro
//  es del PROCESO, no de la instancia de `UserDefaults`** —registrar a través de un suite con UUID
//  deja el valor visible desde cualquier otro `UserDefaults` del proceso— y **no se puede
//  deshacer**. Para la app eso da igual (lo que se registra es justo lo que el proceso uitest
//  quiere), pero convierte al mecanismo en veneno para un unit test: por eso `volatileApply` es
//  inyectable y el pin nunca ejecuta el real sobre estas keys. Se descubrió porque el propio pin
//  se contaminó a sí mismo entre dos de sus tests; sin inyectar habría puesto en rojo a
//  `DataWipeServiceTests` y `HandoverGroupsDomainTests`, que afirman `object(forKey:) == nil` de
//  estas mismas keys sobre almacenes AISLADOS —y el dominio de registro se cuela igual en ellos.
//
//  Y LA PURGA NO ES CINTURÓN, es la mitad que cura: el dominio de registro tiene MENOS prioridad
//  que el persistente, así que sin borrar lo escrito el valor viejo seguiría ganando; y es lo
//  único que limpia los simuladores que ya corrieron la versión anterior. Por eso cada `apply*`
//  purga SIEMPRE, también en la rama que no registra nada.
//
//  AL AÑADIR UN SEAM AQUÍ, BUSCA QUIÉN MÁS LEE ESA KEY Y LA RE-ESCRIBE — es el LAVADO, y no basta
//  con que este fichero haga su parte. `AppPreferences.loadFromDefaults` re-persistía lo que acaba
//  de leer (default hardcoded `false` + store que devuelve `true` ⇒ el `didSet` lo escribía de
//  vuelta), así que convertía en PERMANENTE lo que aquí muere con el proceso: con estos tres seams
//  ya efímeros, las dos keys de onboarding seguían apareciendo en el plist del contenedor tras un
//  launch `-uitest`.
//
//  El arreglo YA NO son dos guards en esas dos propiedades: desde el lavado general (2026-08-05)
//  `loadFromDefaults` no escribe NADA mientras carga (`isLoadingFromDefaults`), así que cualquier
//  key que gane un mirror en `AppPreferences` está cubierta de nacimiento. Lo que sigue habiendo que
//  comprobar es que el lector nuevo no sea OTRO mirror con `didSet` fuera de `AppPreferences`
//  —`SessionState`, `ThemeManager` y `ProTourManager` re-escriben lo que se les asigna— porque a
//  ésos el mecanismo no los cubre.
//
//  DÓNDE VA EL GUARD. Ninguna función de aquí comprueba `UITestHooks.isActive`, igual que
//  `applyUITestProTier(_:)`: el guard es el ÚNICO llamador (`AppBootstrapper.applyUITestHooksEarly`,
//  que solo se invoca bajo `-uitest` dentro de `#if DEBUG`). Sin guard interno, el host de unit
//  tests —que NO lleva `-uitest`— puede ejercitar el comportamiento REAL; con él, el pin no podría
//  probar nada. El call site lo cubre la otra mitad del pin, un source-scan
//  (`YalaTests/UITestSeamPersistenceIsolationTests.swift`).
//
//  Almacén inyectable por la misma razón: el pin de comportamiento corre contra un `UserDefaults`
//  de juguete y puede leer su dominio persistente para afirmar que quedó VACÍO — que es la
//  aserción que carga el peso y la que no se puede hacer sobre `.standard`.
//

import Foundation

#if DEBUG
enum UITestEphemeralDefaults {

    /// Cómo se pone un valor SIN escribirlo.
    ///
    /// Inyectable ÚNICAMENTE para el pin, y no es cosmético: el dominio de registro es del PROCESO
    /// y es irreversible (ver cabecera), así que un test que ejecutara el real sobre estas keys
    /// dejaría el seam puesto para el resto de la corrida. El pin comprueba el real contra una key
    /// de SONDA que no lee nadie, y el cableado del real —que es lo que un doble no puede probar—
    /// por source-scan.
    typealias VolatileApply = (UserDefaults, [String: Any]) -> Void

    static let liveVolatileApply: VolatileApply = { defaults, values in
        defaults.register(defaults: values)
    }

    /// Dominio Grupos ADOPTADO para ESTE proceso (los XCUITest prueban la funcionalidad de Grupos,
    /// no el acto de adoptarla), sin dejar la key escrita.
    ///
    /// Antes esto era `UserDefaults.standard.set(true, forKey:)` en `applyUITestHooksEarly`, y su
    /// purga no existía en ninguna parte: `removeUserPreferenceKeys` excluye esta key A PROPÓSITO
    /// (es una adopción per-device que el wipe de «Vaciar datos» no debe olvidar, con test que lo
    /// pinnea) ⇒ una sola corrida de XCUITest dejaba Grupos adoptado para siempre en ese simulador.
    ///
    /// El dominio de REGISTRO (volátil) es además lo que hace que `GroupsDomainAdoptionMarker`
    /// —que escribe la adopción al entrar al tab— vea la key ya puesta y NO persista nada.
    /// El prompt de notificaciones de Grupos, dado por visto para ESTE proceso.
    ///
    /// Sale la primera vez que hay grupos activos y es un `.alert`, así que TAPA la pantalla y se
    /// come los taps de cualquier suite de Grupos. Hasta ahora nadie lo sufría por una razón
    /// incómoda: `hasSeenGroupsNotificationPrompt` SOBREVIVE entre corridas, así que en una máquina
    /// de siempre ya está puesta y el alert no aparece — las suites estaban en verde gracias a
    /// estado pegajoso, y saltan en cuanto alguien resetea el simulador o corre en una máquina
    /// limpia. Medido el 2026-09-04 al escribir `GroupMembersAdminUITests`.
    ///
    /// No se puede descartar desde el test: los botones de un `.alert` de SwiftUI NO propagan
    /// `accessibilityIdentifier` — verificado en el árbol de runtime, salen con el campo vacío —, y
    /// targetearlos por su texto está prohibido por las convenciones. Así que se apaga en origen.
    ///
    /// Dominio de REGISTRO (volátil) y purga de la key persistida, como sus vecinos: un seam que
    /// deje esto escrito en disco convertiría el problema en permanente para las corridas manuales.
    static func applyGroupsNotificationPromptSeen(
        to defaults: UserDefaults = .standard,
        volatileApply: VolatileApply = liveVolatileApply
    ) {
        defaults.removeObject(forKey: AppPreferences.Keys.hasSeenGroupsNotificationPrompt)
        volatileApply(defaults, [AppPreferences.Keys.hasSeenGroupsNotificationPrompt: true])
    }

    static func applyGroupsBetaUnlocked(
        to defaults: UserDefaults = .standard,
        volatileApply: VolatileApply = liveVolatileApply
    ) {
        defaults.removeObject(forKey: AppPreferences.Keys.groupsBetaUnlocked)
        volatileApply(defaults, [AppPreferences.Keys.groupsBetaUnlocked: true])
    }

    /// Onboarding y Welcome Chooser dados por vistos para ESTE proceso, sin dejar las keys escritas.
    ///
    /// Va incondicional (no solo cuando `seen`), como `applyUITestProTier(_:)`: los launches que
    /// SÍ quieren ver el onboarding (`-uitest-onboarding`, `WelcomeChooserUITests`) necesitan la
    /// purga igual —o más—, porque son justo los que un simulador contaminado deja en verde falso.
    ///
    /// One-shot por proceso: el dominio de registro no se puede "desregistrar", así que llamar
    /// esto dos veces con valores distintos NO revierte el primero. El único llamador lo invoca
    /// una vez, antes del primer render.
    static func applyOnboardingAlreadySeen(
        _ seen: Bool,
        to defaults: UserDefaults = .standard,
        volatileApply: VolatileApply = liveVolatileApply
    ) {
        defaults.removeObject(forKey: AppPreferences.Keys.hasCompletedOnboarding)
        defaults.removeObject(forKey: AppPreferences.Keys.hasShownWelcomeChooser)
        guard seen else { return }
        volatileApply(defaults, [
            AppPreferences.Keys.hasCompletedOnboarding: true,
            AppPreferences.Keys.hasShownWelcomeChooser: true,
        ])
    }

    /// Purga el centinela del seed de categorías **de PRODUCCIÓN**. No registra nada: bajo
    /// `-uitest` el centinela vivo es otro (`CategorySeedSentinel.uiTestKey`), porque el store
    /// también es otro.
    ///
    /// Borrarlo es SEGURO y auto-reparador, y conviene entender por qué: el centinela es una
    /// optimización anti-TOCTOU con respaldo en la base (`seedCategoriesIfNeeded` cuenta las
    /// categorías de usuario cuando el flag está ausente, y lo vuelve a poner si las hay). Quitarlo
    /// solo cuesta un `fetchCount` en el siguiente arranque manual; dejarlo puesto costaba una app
    /// SIN categorías.
    /// Manda la racha de App Attest a una suite PROPIA mientras dure el modo uitest, y purga la que quedó escrita
    /// en el almacén real por corridas anteriores.
    ///
    /// **No se puede resolver con el dominio de registro como sus vecinas de este fichero**: la racha la escribe
    /// código de producción (`GroupsAttestStreakStore.recordRejection`), y `set(_:forKey:)` va al dominio
    /// persistente. Lo que sí tiene la tienda es el seam que sus tests ya usan —`defaults` inyectable— así que el
    /// desvío entero cabe en dos líneas y cubre **toda** escritura de la corrida, no solo la del seam de QA.
    ///
    /// Por qué hace falta, y es la misma clase de fuga que las de arriba: `groupsSync.attestRejectionStreak` no
    /// está en `DataWipeService.removeUserPreferenceKeys` **a propósito** —describe al teléfono, y cerrar sesión no
    /// arregla el attest— así que `-uitest-reset` no la borra. Sin este desvío, una corrida con
    /// `-uitest-groups-attest-terminal` dejaba el veredicto terminal puesto para **todo arranque MANUAL** del
    /// simulador y para el host de unit tests, que comparte bundle: los gestos de cierre y de salir de un grupo lo
    /// leen (`GroupSettingsView`) y ofrecerían perder los cambios sobre un teléfono que atesta perfectamente.
    ///
    /// La purga va SIEMPRE, también cuando el desvío funciona: es lo único que limpia los simuladores que ya
    /// corrieron la versión anterior de este seam.
    static func applyEphemeralAttestStreak(
        purging defaults: UserDefaults = .standard,
        suiteName: String = "yala.uitest.groupsAttestStreak"
    ) {
        defaults.removeObject(forKey: GroupsAttestStreakStore.key)
        guard let suite = UserDefaults(suiteName: suiteName) else { return }
        // Vaciada en cada arranque: la racha de la corrida anterior no es estado que ninguna corrida quiera heredar.
        suite.removePersistentDomain(forName: suiteName)
        GroupsAttestStreakStore.defaults = suite
    }

    static func purgeCategorySeedSentinel(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: CategorySeedSentinel.productionKey)
    }

    /// Purga el sobre de la puerta del invitado (`GroupInviteResumeStore`), que bajo `-uitest` **se puede
    /// escribir y no lo consume nadie**: su único consumidor es el boot-wipe, y ése sale por su
    /// `guard !isRunningTests, !isUITesting` antes de tocar nada. Sin esta purga, una corrida que llegue al
    /// gesto de la puerta deja la key puesta en el simulador para todas las suites siguientes y para
    /// cualquier arranque manual — que es la clase de residuo del QA manual que este fichero existe para
    /// cerrar (el molde es el de `groupsBetaUnlocked` de aquí arriba).
    ///
    /// Purga y no seam: ninguna corrida quiere el sobre PUESTO, así que no hay nada que registrar.
    static func purgeGroupInviteResumeEnvelope(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: GroupInviteResumeStore.key)
    }
}
#endif

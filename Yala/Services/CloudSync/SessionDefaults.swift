//
//  SessionDefaults.swift
//  Yala
//
//  **La ÚNICA puerta que decide EN QUÉ dominio de `UserDefaults` escribe la app.**
//
//  Es la mitad que le faltaba a la frontera M1. La otra —el iCloud KV— se cerró el 2026-08-12 en
//  `25a36be2` con `OwnerKeyValueStore`, y este fichero es su gemelo: mismo problema visto desde el
//  almacén LOCAL del teléfono. Cuando alguien entra a Yala con su cuenta en el móvil de otra persona
//  (sesión secundaria), hoy escribe sus preferencias en el cajón del dueño: al devolver el móvil, el
//  dueño se encuentra su nombre y su divisa cambiados, su barra de pestañas como la dejó la visita, y
//  su permiso de Grupos retirado. Sus datos financieros sí están a salvo —viven en un store aparte—;
//  lo que se estropea es la configuración.
//
//  **Por qué una puerta y no un guard por escritor** (decisión del owner, 2026-08-13, misma razón que
//  `OwnerKeyValueStore`): «acordarse en N sitios» ya falló tres veces en esta frontera, y aquí los
//  sitios son 307 `UserDefaults.standard` repartidos por 86 ficheros. Un sitio que decide, y un
//  source-scan con conteo que impide que exista un camino nuevo.
//
//  **El riesgo de este cambio NO está en el escritor, está en los LECTORES.** Un escritor movido al
//  cajón de la visita con su lector todavía en `.standard` produce una app incoherente durante toda
//  la visita —ella toca un ajuste y no pasa nada, o ve preferencias del dueño mezcladas con las
//  suyas—, que es PEOR que el bug actual. De ahí la regla de fase: escritor y lectores de una key
//  viajan en el MISMO commit.
//
//  ## El contrato, y por qué cada cláusula existe
//
//  1. **Instancia CACHEADA por nombre de suite.** Dos `UserDefaults(suiteName: X)` son objetos
//     DISTINTOS, y `NotificationCenter.addObserver(object:)` filtra por identidad del emisor:
//     `AppPreferences.registerObservers()` se registra con `object: defaults`
//     (`AppPreferences.swift:894`), así que construir el suite inline en cada llamada dejaría a
//     `AppPreferences` sin recargar NUNCA — en silencio, durante toda la sesión secundaria. Es
//     exactamente la lección que `OwnerKeyValueStore.notificationSource` (`:155-162`) existe para
//     documentar, en su versión local.
//  2. **Nombre resuelto POR LLAMADA, jamás capturado en un `let`.** Lo exige la ventana de entrada:
//     `SecondaryEntryLogic.begin` activa el descriptor CON EL PROCESO DEL DUEÑO VIVO
//     (`WelcomeCloudSignInView.swift:801-805`) y el relanzamiento llega después (`:812`). En esos
//     segundos se escribe el registro de consentimiento RGPD de la invitada (`:810`). Una resolución
//     capturada al arranque lo dejaría en el cajón del dueño. El repo ya depende de esta propiedad:
//     el comentario de `:806-809` declara que ese orden ES el fix porque `PrefsSyncBehavior.resolve`
//     pregunta por el descriptor vivo en cada llamada.
//  3. **Los LECTORES se congelan al arranque, y eso es deliberado.** `AppPreferences` toma su store
//     una vez. Un lector reactivo sería daño NUEVO: si re-apunta durante la ventana de entrada, los
//     lectores del árbol vivo del dueño leerían un cajón todavía vacío, `hasCompletedOnboarding`
//     daría `false` y se montaría la cadena Welcome debajo del cover de relanzamiento — el brick que
//     `SwiftDataConfiguration.swift:803` dice que jamás debe ocurrir in-session.
//
//  ## La excepción de entorno de test
//
//  Bajo `isRunningTests` Y bajo `isUITesting` la puerta devuelve el dominio del dueño. No es
//  comodidad: `AppBootstrapper.swift:658` planta el descriptor en los XCUITest, pero lo hace en el
//  dominio VOLÁTIL (`UITestEphemeralDefaults.applySecondarySession` → `volatileApply`, sin rastro en
//  disco) mientras que un suite SÍ persistiría; y los dos anclajes del ciclo de vida están apagados
//  en ambos entornos (`SwiftDataConfiguration.swift:811` y `:876`). Sin la excepción nacería un cajón
//  que nadie siembra, nadie destruye y ninguna purga alcanza — el precedente exacto de
//  `groupsDomainSealedForFreshStart`, que dejó 14 tests rojos «hasta que alguien borre el simulador».
//  Los tests ejercitan la puerta por el parámetro `isTestEnvironment`, molde de las variantes
//  inyectables de `SwiftDataConfiguration`.
//
//  **La excepción cubre las TRES operaciones, no solo la resolución**, y eso no es simetría
//  cosmética. Resolver a `.standard` mientras la siembra sigue creando el suite deja en el disco del
//  simulador un cajón que la puerta declara inexistente: nadie lo lee, nadie lo destruye, y el
//  sentinel de siembra que hay dentro sobrevive entre corridas. Es la misma basura que se quería
//  evitar, entrando por la puerta de al lado — y se vio en cuanto los hooks de frontera empezaron a
//  llamar a la siembra con su `userID` fijo de test.
//
//  ## Fallo cerrado, y por qué se degrada en vez de brickear
//
//  Si el suite no se puede abrir, la puerta devuelve el dominio del dueño y deja un canario. Devolver
//  un store vacío dejaría a la app sin preferencias y sin onboarding completado: un brick es peor que
//  el bug que este fichero cierra. La degradación es al comportamiento de HOY, y es observable.
//

import Foundation

/// **`nonisolated`, como `SecondarySessionStore`**, y no por copiar al vecino: el target `YalaTests`
/// NO lleva `SWIFT_DEFAULT_ACTOR_ISOLATION`, así que sus tests son `nonisolated` y son ellos quienes
/// ejercitan los dos hooks de frontera. Todo lo que esta puerta consume son constantes inmutables
/// (`isRunningTests`, `isUITesting`, `AppPreferences.Keys`), marcadas `nonisolated` en su origen —
/// que es donde corresponde, porque un `static let` de un `Bool` o de un `String` no necesita actor.
nonisolated enum SessionDefaults {

    // MARK: - El nombre del dominio

    /// Prefijo del suite de sesión. El sufijo es el `sub` de la cuenta nube de la visita.
    static let suitePrefix = "yala.session."

    /// Nombre del dominio para un `sub`, o `nil` si no queda nada utilizable tras sanear.
    ///
    /// El saneado es DETERMINISTA (mismo `sub` ⇒ mismo nombre, que es lo que permite destruirlo
    /// después) y conservador: un `suiteName` con caracteres de dominio inválidos no es un error
    /// ruidoso en `UserDefaults`, es un dominio que se comporta raro. Los `sub` de la nube son UUID,
    /// así que en la práctica el filtro no quita nada; existe para que un formato nuevo de
    /// identificador no rompa la frontera en silencio.
    static func suiteName(forUserID userID: String) -> String? {
        let sanitized = userID.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
        guard !sanitized.isEmpty else { return nil }
        return suitePrefix + sanitized
    }

    // MARK: - La puerta

    /// El dominio en el que la app debe escribir AHORA. Computed a propósito (cláusula 2).
    static var current: UserDefaults { resolve() }

    /// Variante inyectable — `owner` para tests con `UserDefaults` aislado, `isTestEnvironment` para
    /// poder ejercitar la puerta desde la suite (donde por defecto está desactivada).
    ///
    /// El default de `isTestEnvironment` se evalúa EN CADA LLAMADA, igual que el resto de la
    /// resolución: nada aquí puede quedar capturado.
    static func resolve(
        owner: UserDefaults = .standard,
        isTestEnvironment: Bool = SwiftDataConfiguration.isRunningTests || SwiftDataConfiguration.isUITesting
    ) -> UserDefaults {
        guard !isTestEnvironment else { return owner }
        guard let userID = SecondarySessionStore.activeUserID(owner) else { return owner }
        guard let name = suiteName(forUserID: userID) else {
            CloudSyncBreadcrumb.sessionDomainUnavailable(reason: "userID sin caracteres utilizables")
            return owner
        }
        guard let suite = suite(named: name) else {
            CloudSyncBreadcrumb.sessionDomainUnavailable(reason: "UserDefaults(suiteName:) devolvió nil")
            return owner
        }
        return suite
    }

    // MARK: - La caché (cláusula 1)

    nonisolated(unsafe) private static var cachedSuites: [String: UserDefaults] = [:]
    private static let cacheLock = NSLock()

    /// La instancia ÚNICA para un nombre de suite. Ver cláusula 1: dos instancias del mismo suite
    /// rompen los observers registrados con `object:` sin dar un solo síntoma.
    static func suite(named name: String) -> UserDefaults? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = cachedSuites[name] { return cached }
        guard let created = UserDefaults(suiteName: name) else { return nil }
        cachedSuites[name] = created
        return created
    }

    /// Suelta la instancia cacheada. Se llama al destruir el dominio: dejarla viva serviría lecturas
    /// de un cajón que ya no existe.
    static func forgetCachedSuite(named name: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cachedSuites.removeValue(forKey: name)
    }

    // MARK: - Ciclo de vida · siembra (ENTRADA)

    /// Keys de DISPOSITIVO que el cajón recién nacido hereda del dueño.
    ///
    /// Decisión del owner (2026-08-13): el cajón nace **vacío con las keys de dispositivo sembradas**
    /// — ni vacío del todo (la visita vería el Welcome sobre un store secundario vacío: el brick) ni
    /// copia del dueño (sus preferencias no son de ella).
    ///
    /// Son las DOS del healing de entrada (`SwiftDataConfiguration.swift:916-917`), y
    /// `hasShownYalaAIOnboarding` NO está: medido, el healing de hoy no lo escribe (decisión D4 del
    /// owner — pasa a las keys ambiguas del inventario de F2).
    static var seededDeviceKeys: [String] {
        [AppPreferences.Keys.hasCompletedOnboarding, "hasShownWelcomeChooser"]
    }

    /// Sentinel de siembra. Vive EN EL CAJÓN, y eso es la mitad del diseño: un guard que leyera
    /// `.standard` —donde el dueño tiene el flag a `true`— concluiría «ya sembrado» y el cajón no se
    /// sembraría jamás, con lo que el brick del Welcome pasaría de caso raro a caso normal.
    static let seedSentinelKey = "session.deviceKeysSeeded"

    /// Siembra el cajón de la visita con las keys de dispositivo del dueño. Idempotente por sentinel
    /// PROPIO (no colgado de `entryPurgeDone`: con el cajón, la siembra deja de ser kill-recovery y
    /// pasa a ser el camino normal).
    ///
    /// **ADITIVA, y no es un detalle.** El cajón ya puede tener datos cuando esto corre: entre que la
    /// visita confirma la entrada y que el proceso muere hay unos segundos con su sesión ya activa,
    /// y en ellos se escribe su registro de consentimiento RGPD. Borrar-y-reescribir aquí lo pisaría.
    /// Por eso cada key solo se escribe si el cajón NO la tiene ya.
    ///
    /// Copia el VALOR del dueño, no escribe `true` a ciegas: si el dueño no completó su onboarding,
    /// afirmarlo en el cajón sería inventarse un hecho.
    static func seedDeviceKeysIfNeeded(
        from owner: UserDefaults,
        forUserID userID: String,
        isTestEnvironment: Bool = SwiftDataConfiguration.isRunningTests || SwiftDataConfiguration.isUITesting
    ) {
        guard !isTestEnvironment else { return }
        guard let name = suiteName(forUserID: userID), let session = suite(named: name) else {
            CloudSyncBreadcrumb.sessionDomainUnavailable(reason: "siembra sin dominio para \(userID)")
            return
        }
        guard !session.bool(forKey: seedSentinelKey) else { return }
        for key in seededDeviceKeys where session.object(forKey: key) == nil {
            session.set(owner.bool(forKey: key), forKey: key)
        }
        session.set(true, forKey: seedSentinelKey)
        CloudSyncBreadcrumb.sessionDomainSeeded()
    }

    // MARK: - Ciclo de vida · destrucción (SALIDA)

    /// Borra el cajón de la visita. Devuelve `false` si no había nombre con el que componerlo.
    ///
    /// **El `userID` va por parámetro EXPLÍCITO y el fallo es cerrado, por dos razones que costaron
    /// una revisión entera:** en el punto donde esto se llama el descriptor sigue vivo pero está a
    /// una línea de borrarse (`SwiftDataConfiguration.swift:856`), y después de esa línea ya no hay
    /// `sub` con el que componer el nombre — el cajón quedaría HUÉRFANO PARA SIEMPRE en el móvil del
    /// dueño, con el nombre, la divisa y la barra de la invitada dentro. Y la variante peor: resolver
    /// la puerta en ese punto y llamar `removePersistentDomain` sobre lo que devuelva **borraría el
    /// `UserDefaults` entero del dueño**. Por eso aquí no se resuelve nada: se compone el nombre a
    /// partir del `sub` recibido, y si no lo hay no se toca nada.
    @discardableResult
    static func destroySuite(
        forUserID userID: String,
        isTestEnvironment: Bool = SwiftDataConfiguration.isRunningTests || SwiftDataConfiguration.isUITesting
    ) -> Bool {
        guard !isTestEnvironment else { return false }
        guard let name = suiteName(forUserID: userID) else {
            CloudSyncBreadcrumb.sessionDomainUnavailable(reason: "destrucción sin nombre para \(userID)")
            return false
        }
        // Sobre la instancia del PROPIO suite: `removePersistentDomain` desde otro dominio deja el
        // borrado sin aplicar cuando el suite tiene una instancia viva (la que la caché mantiene).
        suite(named: name)?.removePersistentDomain(forName: name)
        forgetCachedSuite(named: name)
        return true
    }
}

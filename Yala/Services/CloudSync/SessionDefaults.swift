//
//  SessionDefaults.swift
//  Yala
//
//  **El CAJÓN de preferencias de una sesión secundaria (M1). La PUERTA que lo elegía ya no existe.**
//
//  Hasta el 2026-09-12 este fichero decidía en qué dominio de `UserDefaults` escribía la app: `.standard`
//  para el dueño del teléfono, o `yala.session.<sub>` mientras hubiera una invitada dentro. Esa puerta
//  —`current`, `resolve(owner:isTestEnvironment:)` y `sessionSuite(...)`— se retiró porque **en
//  producción nunca llegó a actuar**: la entrada a sesión secundaria jamás se encendió, así que resolvía
//  a `.standard` para el 100 % del parque. En el mismo cambio se apagó el encendido compilado de esa
//  entrada (`CloudSyncFlags.secondarySessionCompiledDefault`), porque retirar el aislamiento dejando
//  abierta la entrada convierte un rollout en una fuga.
//
//  **Lo que queda vivo aquí es el cajón en sí** —crearlo, cachearlo, sembrarlo y destruirlo— y sus dos
//  únicos consumidores son los hooks de frontera de `SwiftDataConfiguration`. Todo esto cae con M1 en
//  `shell-derives-from-two-session-axes`.
//
//  **Las dos lecciones que sobreviven al borrado, porque se pagaron con incidentes:**
//
//  1. **Instancia CACHEADA por nombre de suite.** Dos `UserDefaults(suiteName: X)` son objetos DISTINTOS
//     y `NotificationCenter.addObserver(object:)` filtra por identidad del emisor, así que construir el
//     suite inline deja observers que no disparan nunca, **en silencio**. Sigue vigente para `suite(named:)`.
//  2. **Escritor y lectores de una key viajan en el MISMO commit.** Un escritor movido de dominio con su
//     lector atrás produce una app incoherente, que es peor que el bug que se arreglaba. La regla vale
//     para cualquier cambio de dominio, no solo para el que ya no existe.
//
import Foundation

enum SessionDefaults {

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

    // MARK: - La puerta RETIRADA

    // `current`, `resolve(owner:isTestEnvironment:)` y `sessionSuite(owner:isTestEnvironment:)` se
    // retiraron el 2026-09-12: eran el dominio por sesión que leían 49 ficheros en 155 líneas, y los tres
    // resolvían a `.standard` para el 100 % del parque (el descriptor nunca pudo activarse en
    // producción). Lo que queda debajo es el cajón en sí, que todavía usan los dos hooks de M1 en
    // `SwiftDataConfiguration`, y cae con ellos.

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

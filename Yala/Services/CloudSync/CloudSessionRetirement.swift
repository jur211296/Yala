//
//  CloudSessionRetirement.swift
//  Yala
//
//  **Retirar la sesión en la nube de quien usó ANTES este teléfono.** Dos fronteras, dos consumidores, y
//  los dos no son simetría sino la diferencia entre un arranque y un gesto.
//
//  ## El problema, y por qué no se cierra puerta a puerta
//
//  El JWT de Supabase vive en su propio llavero (`CloudAuthKeychainStorage`, service
//  `com.yala.cloudauth`, `AfterFirstUnlockThisDeviceOnly`) y **sobrevive a borrar la app** — medido en
//  dispositivo para el keyId de App Attest, que usa la misma accesibilidad
//  (`.claude/rules/gateway-attest.md`). Hasta el 2026-09-17 nada lo retiraba: ni «Empezar desde cero»
//  (`DataWipeService.wipeLocalGroupsDomain` lo decía en su cabecera) ni la reinstalación. Con la sesión
//  viva, cada puerta que la reusa —el Welcome, «Activar Yala completo», la hoja de Grupos, la tarjeta de
//  adopt— le deja a la persona NUEVA las finanzas o los grupos en la cuenta de la ANTERIOR.
//
//  Cerrarlas una a una no funciona: `fresh-start-keeps-a-groups-session-that-migrate-promotes` cerró la
//  de «Activar la nube» y el ticket hermano midió que tras reinstalar no queda sello, así que ninguna
//  regla de esa puerta lo ve. La raíz es la sesión. Decisión de Jürgen (2026-09-17): **las dos mitades**
//  —cerrarla en el relevo y purgarla en el primer arranque tras instalar—; quien reinstala su propia app
//  vuelve a entrar.
//
//  ## Un arm durable, y DOS consumidores con física distinta
//
//  Los dos disparadores son síncronos —`wipeLocalGroupsDomain` lanza, y el arranque pre-mount no tiene
//  dónde esperar— así que lo que se escribe es un arm durable. Lo que lo consume depende de si hay un SDK
//  vivo al otro lado:
//
//  · **`purgeIfArmed()` — PRE-MOUNT, síncrono, sin red.** Es el consumidor PRINCIPAL. Corre como primera
//    cosa del proceso, cuando `CloudAuthService.shared` —un `static let` perezoso— **todavía no se ha
//    construido**: no hay `AuthClient`, no hay ticker de auto-refresh, no hay nada que pueda reponer lo
//    que borra, y no hay ninguna llamada de red. Cubre la reinstalación y repara cualquier relevo cuyo
//    `Task` muriera a medias. Cuando el `AuthClient` se construya después, leerá un llavero vacío.
//  · **`retireForHandover()` — EN PROCESO, asíncrono.** El relevo no relanza, así que ahí el SDK ya está
//    vivo con la sesión cargada en memoria y hay que decírselo: `signOut()` limpia esa copia, el perfil
//    capturado, el provider, la caché de entitlement y el SDK de Google. Va en un `Task` y **no bloquea
//    ninguna pantalla**.
//
//  **Por qué el consumo NO está en `AppBootstrapper`, que era la primera versión:** `signOut()` termina en
//  `client.signOut(scope: .local)`, que habla con el servidor sobre el `URLSession` por defecto del SDK —
//  sin tope propio, 60 s de `timeoutIntervalForRequest`. Un `await` ahí deja el `defer` de `bootstrap` sin
//  ejecutar, y con él el blocker `bootstrapPending`: con un portal cautivo o un servidor que no contesta,
//  el primerísimo arranque se queda **sin montar el Welcome y sin drenar un solo intent**. Lo cazó la
//  review adversarial. Pre-mount no hay red y no hay nada que bloquear.
//
//  ## `signOut()` NO para al SDK, y por eso la purga se VERIFICA
//
//  Medido: `stopAutoRefreshToken` no aparece en ningún sitio de este repo, y el `signOut` del SDK tampoco
//  cancela un refresco en vuelo. ⇒ en el camino EN PROCESO, un refresco que ya había arrancado puede
//  aterrizar después del `SecItemDelete` y volver a escribir la sesión. Por eso `retireIfArmed` relee el
//  service (`isEmpty()`) y **solo desarma si quedó vacío**; si no, el arm sobrevive y el `purgeIfArmed`
//  del arranque siguiente —que sí es race-free— lo termina. Sin esa relectura el retiro se daba por hecho
//  y la sesión de la persona anterior quedaba resucitada en silencio y para siempre.
//
//  ## Failure-safe
//
//  El arm **solo se desarma si el llavero quedó vacío de verdad**. Reintentarlo es barato justamente
//  porque el consumidor principal es local: un `SecItemDelete` que falla no le cierra la sesión a nadie,
//  solo deja el trabajo para el arranque siguiente.
//
//  ## Lo que este retiro NO toca, y es deliberado
//
//  · **El cursor de Grupos** (`GroupSyncCursor`). La regla de área lo conserva en toda frontera de
//    usuario porque es la BARRERA contra el corpus del anterior. Cerrar la sesión no invierte su signo:
//    está indexado por `groupID` (los grupos de la persona nueva son otros IDs y bajan enteros), un
//    re-join ya lo resetea (`cursorResetGroupIDs`), y si ESTE retiro falla el cursor es lo único que
//    queda. El par coherente sigue siendo **outbox muerto + cursor vivo**.
//  · **El iCloud-KV del Apple ID** (el faro, la asociación de Grupos). Es del Apple ID, no del teléfono:
//    borrar ahí viaja al iPad del dueño. Y es justo lo que le da a quien reinstala su propia app el
//    camino de vuelta — «Ya tengo una cuenta → Entrar con Apple/Google».
//  · **El SELLO del handover** (`groupsDomainSealedForFreshStart`). Retirar la sesión y sellar el dominio
//    son decisiones distintas: el sello es irreversible en este teléfono y se lo comería quien reinstala
//    su PROPIA app. Lo escribe `wipeLocalGroupsDomain`, y solo donde de verdad hay un corpus ajeno que
//    apartar.
//

import Foundation

nonisolated enum CloudSessionRetirement {

    // MARK: - Keys

    /// «Hay una sesión de otra persona que retirar en este teléfono.» Durable a propósito: sobrevive a
    /// un kill entre el gesto que la arma y el retiro.
    ///
    /// Prefijo `cloudSync.` para que `DataWipeService.removeUserPreferenceKeys` la excluya — esa lista
    /// es de keys NOMBRADAS y el prefijo está documentado como exclusión deliberada. No es una
    /// preferencia de la persona: es infra del propio relevo, igual que los arms del sign-out.
    static let armedKey = "cloudSync.previousPersonSessionRetirementArmed"

    /// «Este contenedor ya pasó por aquí.» La escribe el primer arranque que corre esta versión, sea una
    /// instalación nueva o una ACTUALIZACIÓN, y a partir de ahí nadie vuelve a preguntar nada.
    ///
    /// Restaurar el teléfono desde una copia de seguridad repone las preferencias Y el llavero, así que a
    /// partir del primer arranque la marca está y no se arma nada — que es lo correcto: es la misma persona.
    static let installSeenKey = "cloudSync.installSeen"

    /// Las huellas de «esta app YA se usó en este contenedor». Se leen con sus literales porque esto
    /// corre en `@main`, antes de que exista ningún `AppBootstrapper` — igual que hacen los dos wipes de
    /// `SwiftDataConfiguration`.
    ///
    /// `reviewFirstLaunchDate` es la más fuerte de las dos: la escribe el primer bootstrap de CUALQUIER
    /// instalación desde el 2026-03-16 y **`DataWipeService.removeUserPreferenceKeys` no la nombra**
    /// (`review*` es una exclusión deliberada), así que sobrevive a «Vaciar datos» y al relevo.
    /// `hasCompletedOnboarding` es su respaldo por si un teléfono viejo nunca llegó a escribirla.
    ///
    /// Los dos literales llevan test de paridad contra su productor real: el de `ReviewPromptService` es
    /// `private`, así que solo un source-scan puede casarlos.
    static let priorInstallEvidenceKeys = ["reviewFirstLaunchDate", "hasCompletedOnboarding"]

    // MARK: - Los dos disparadores

    /// **El relevo.** Lo llama `DataWipeService.wipeLocalGroupsDomain`, el escritor común de los tres
    /// call-sites de «Empezar desde cero». Síncrono y durable: escribir la key es todo lo que tiene que
    /// sobrevivir a un kill.
    static func arm(defaults: UserDefaults) {
        defaults.set(true, forKey: armedKey)
    }

    /// **El primer arranque tras instalar.** Corre PRE-MOUNT, al lado de
    /// `SecondarySessionRetirement.purgeIfNeeded()`, con sus mismas guardas de entorno.
    ///
    /// **Va ANTES de `SwiftDataConfiguration.performSignOutWipeIfArmed()` y el orden importa**: ese hook
    /// borra los archivos del store, que son una de las dos evidencias de instalación previa.
    @MainActor
    static func armIfFirstLaunchAfterInstall() {
        guard !SwiftDataConfiguration.isRunningTests, !SwiftDataConfiguration.isUITesting else { return }
        armIfFirstLaunchAfterInstall(
            defaults: .standard,
            hasPriorInstallEvidence: SwiftDataConfiguration.personalStoreFileExists()
                || priorInstallEvidenceKeys.contains { UserDefaults.standard.object(forKey: $0) != nil })
    }

    /// Variante inyectable.
    ///
    /// **`hasPriorInstallEvidence` NO es una precaución: sin él, la primera ACTUALIZACIÓN cierra la sesión
    /// de todo el parque.** `installSeenKey` nace con esta versión, así que en cada teléfono que ya tiene
    /// Yala está ausente — «ausente» significa «primera vez que corre este código», no «app recién
    /// instalada», y confundirlos armaba el retiro para todo el mundo el día del update.
    ///
    /// **La dirección del fallo se elige a propósito: ante la duda, NO se arma.** No armar deja el bug
    /// vivo para un teléfono que cambió de dueño; armar de más cierra la sesión de quien no lo pidió, y
    /// esa población es el parque entero. Por eso las evidencias van en `||`.
    ///
    /// **El arm se escribe ANTES que la marca, y el orden es lo kill-safe.** Al revés, un kill entre las
    /// dos dejaría la marca puesta y el arm perdido: la sesión de la persona anterior sobreviviría para
    /// siempre, sin que ningún arranque volviera a mirar.
    ///
    /// - Returns: `true` si este arranque armó el retiro.
    @discardableResult
    static func armIfFirstLaunchAfterInstall(
        defaults: UserDefaults, hasPriorInstallEvidence: Bool
    ) -> Bool {
        guard !defaults.bool(forKey: installSeenKey) else { return false }
        guard !hasPriorInstallEvidence else {
            // Actualización sobre una instalación viva: no hay relevo que atender, pero la marca se
            // escribe igual para que este arranque sea el único que se lo pregunte.
            defaults.set(true, forKey: installSeenKey)
            return false
        }
        arm(defaults: defaults)
        defaults.set(true, forKey: installSeenKey)
        return true
    }

    // MARK: - El consumidor PRINCIPAL: pre-mount, síncrono, sin red

    /// Borra el llavero de auth si hay arm. **Corre PRE-MOUNT y esa coordenada es todo el diseño:** aquí
    /// `CloudAuthService.shared` todavía no existe, así que no hay copia en memoria que limpiar, no hay
    /// auto-refresh que pueda reponer nada, y no hay ninguna llamada de red delante de la primera pantalla.
    ///
    /// Bajo tests y bajo XCUITest no corre: no hay relevo que atender y tocar el llavero real solo añadiría
    /// ruido entre corridas.
    @MainActor
    static func purgeIfArmed() {
        guard !SwiftDataConfiguration.isRunningTests, !SwiftDataConfiguration.isUITesting else { return }
        purgeIfArmed(defaults: .standard)
    }

    /// Variante inyectable.
    ///
    /// **No relee el llavero para verificar, y aquí sí puede no hacerlo**: lo que obliga a verificar en el
    /// camino en proceso es el auto-refresh del SDK, y en este punto del arranque ese SDK no está
    /// construido. Un `purgeAll()` que devuelve `true` aquí es definitivo.
    ///
    /// - Returns: `true` si había arm y el llavero quedó limpio.
    @discardableResult
    static func purgeIfArmed(
        defaults: UserDefaults,
        purgeKeychain: () -> Bool = { CloudAuthKeychainStorage().purgeAll() }
    ) -> Bool {
        guard defaults.bool(forKey: armedKey) else { return false }
        guard purgeKeychain() else {
            CloudSyncBreadcrumb.previousPersonSessionRetirementIncomplete()
            return false
        }
        defaults.removeObject(forKey: armedKey)
        CloudSyncBreadcrumb.previousPersonSessionRetired()
        return true
    }

    // MARK: - El consumidor EN PROCESO: el relevo

    /// Arma **y dispara en este proceso**. Es lo que necesita el relevo: ahí no hay relanzamiento, y la
    /// persona nueva entra al onboarding a un toque de las puertas que reusarían la sesión.
    ///
    /// El disparo es un `Task` porque el retiro es asíncrono y el escritor no lo es. **Si ese `Task` no
    /// llega a terminar —un kill, un refresco que repone, un fallo del llavero— el arm sobrevive y lo
    /// termina el `purgeIfArmed` del arranque siguiente.** Esa es la red: el sello del handover NO lo es,
    /// porque solo lo escribe `wipeLocalGroupsDomain` y hay ramas de relevo que no purgan el dominio.
    ///
    /// **Los seams se propagan al `Task`, y no es ceremonia.** Sin ellos, cualquier test que llame a esta
    /// función ejecuta el retiro DE VERDAD —`CloudAuthService.shared.signOut()`, que toca singletons antes
    /// incluso de su `guard let client`, y un `SecItemDelete` sobre el llavero del host— en una tarea
    /// huérfana que sobrevive al test y cae sobre la suite vecina. Lo cazó la review adversarial.
    @MainActor
    static func retireForHandover(
        defaults: UserDefaults = .standard,
        signOut: @escaping () async -> Void = {
            // **La guarda de entorno va DENTRO del seam, y ese es el sitio.** En las funciones sin
            // argumentos dejaba fuera justo la mitad que toca el mundo real: un XCUITest que recorra
            // «Empezar desde cero» dispara `retireForHandover`, y sin guarda eso era un `signOut()` de
            // verdad —con su `StoreKitManager.updateSubscriptionStatus()`— sobre el simulador, en una
            // tarea que sobrevive al caso. Lo cazó la review adversarial.
            guard !SwiftDataConfiguration.isRunningTests, !SwiftDataConfiguration.isUITesting else { return }
            await CloudAuthService.shared.signOut()
        },
        purgeKeychain: @escaping () -> Bool = {
            guard !SwiftDataConfiguration.isRunningTests, !SwiftDataConfiguration.isUITesting else { return true }
            return CloudAuthKeychainStorage().purgeAll()
        },
        isKeychainEmpty: @escaping () -> Bool = {
            guard !SwiftDataConfiguration.isRunningTests, !SwiftDataConfiguration.isUITesting else { return true }
            return CloudAuthKeychainStorage().isEmpty()
        }
    ) {
        arm(defaults: defaults)
        Task {
            await retireIfArmed(defaults: defaults, signOut: signOut,
                                purgeKeychain: purgeKeychain, isKeychainEmpty: isKeychainEmpty)
        }
    }

    /// Consume el arm con el proceso vivo: le dice al SDK que la sesión se acabó y purga el llavero.
    ///
    /// - Parameters:
    ///   - signOut: para al SDK y limpia su estado en memoria. Ver el porqué del ORDEN en la cabecera.
    ///   - purgeKeychain: barre el service `com.yala.cloudauth` entero. `false` = no se desarma.
    ///   - isKeychainEmpty: relee el service. `false` = el auto-refresh del SDK repuso la sesión durante
    ///     el `await`, así que el arm se CONSERVA y lo termina el arranque siguiente.
    /// - Returns: `true` si había arm y el llavero quedó vacío de verdad.
    @discardableResult
    @MainActor
    static func retireIfArmed(
        defaults: UserDefaults = .standard,
        signOut: () async -> Void = {
            // **La guarda de entorno va DENTRO del seam, y ese es el sitio.** En las funciones sin
            // argumentos dejaba fuera justo la mitad que toca el mundo real: un XCUITest que recorra
            // «Empezar desde cero» dispara `retireForHandover`, y sin guarda eso era un `signOut()` de
            // verdad —con su `StoreKitManager.updateSubscriptionStatus()`— sobre el simulador, en una
            // tarea que sobrevive al caso. Lo cazó la review adversarial.
            guard !SwiftDataConfiguration.isRunningTests, !SwiftDataConfiguration.isUITesting else { return }
            await CloudAuthService.shared.signOut()
        },
        purgeKeychain: () -> Bool = {
            guard !SwiftDataConfiguration.isRunningTests, !SwiftDataConfiguration.isUITesting else { return true }
            return CloudAuthKeychainStorage().purgeAll()
        },
        isKeychainEmpty: () -> Bool = {
            guard !SwiftDataConfiguration.isRunningTests, !SwiftDataConfiguration.isUITesting else { return true }
            return CloudAuthKeychainStorage().isEmpty()
        }
    ) async -> Bool {
        guard defaults.bool(forKey: armedKey) else { return false }
        await signOut()
        guard purgeKeychain(), isKeychainEmpty() else {
            CloudSyncBreadcrumb.previousPersonSessionRetirementIncomplete()
            return false
        }
        defaults.removeObject(forKey: armedKey)
        CloudSyncBreadcrumb.previousPersonSessionRetired()
        return true
    }
}

//
//  UITestSeamPersistenceIsolationTests.swift
//  YalaTests
//
//  Los tres seams de `-uitest` que PERSISTÍAN, cerrados el 2026-08-05. Hermano de
//  `UITestProTierIsolationTests`, que cerró el primero de la familia (`-uitest-pro`).
//
//  POR QUÉ EXISTE. El scheme `Yala Dev` usa el MISMO bundle (`…yala.dev`) para el host de los
//  XCUITest y para el de los unit tests ⇒ `UserDefaults.standard` es un único almacén compartido
//  que SOBREVIVE a la corrida. Estos tres se escribían ahí en todo launch `-uitest` y su víctima
//  no eran los tests sino un **ARRANQUE MANUAL** de Yala Dev en ese simulador — que es justo el
//  observador al que nadie mira cuando la suite está verde:
//
//    · `groupsBetaUnlocked`   — el gate beta de Grupos quedaba desbloqueado PARA SIEMPRE, porque
//                               `removeUserPreferenceKeys` excluye esa key a propósito y nadie más
//                               la borraba.
//    · `hasCompletedOnboarding` + `hasShownWelcomeChooser` — la app se abría saltándose onboarding
//                               y Welcome Chooser.
//    · `seedCategoriesExecuted` — el peor: el centinela vive en el `UserDefaults` COMPARTIDO y los
//                               datos en stores DISTINTOS (`YalaModel-UITest` vs el personal) ⇒ un
//                               arranque manual con el store personal vacío hacía early-return y se
//                               quedaba **sin categorías**.
//
//  SON DOS MITADES POR SEAM Y NINGUNA CUBRE A LA OTRA. El comportamiento prueba que los métodos no
//  dejan rastro y que purgan lo ya escrito; el source-scan prueba que el bootstrap LLAMA a esos
//  métodos y no vuelve a escribir las keys a mano. El host de unit tests no lleva `-uitest`, así
//  que el call site real (`AppBootstrapper.applyUITestHooksEarly`) es inalcanzable desde aquí: un
//  `UserDefaults.standard.set(true, forKey:)` que volviera ahí reintroduciría los tres bugs enteros
//  con todos los tests de comportamiento en VERDE.
//
//  EL ESCÁNER VA ACOTADO AL CUERPO de `applyUITestHooksEarly`, no al fichero: `AppBootstrapper`
//  escribe `groupsBetaUnlocked` de verdad en el camino de invitación (`persistBackendInviteIntent`),
//  que es PRODUCCIÓN y debe seguir ahí. Sobre el fichero entero solo se podría comprobar un número
//  mágico, y además vale la lección de `TestProcessGuardTests`: un rango demasiado ancho comprueba
//  que el símbolo EXISTE, no que alguien lo llame.
//
//  Y POR QUÉ EL PIN NO EJECUTA EL MECANISMO REAL SOBRE ESTAS KEYS. Medido escribiendo este mismo
//  fichero: `UserDefaults.register(defaults:)` escribe en el dominio de REGISTRO, que es **del
//  PROCESO y no de la instancia** —registrar a través de un suite con UUID deja el valor visible
//  desde cualquier otro `UserDefaults`— y **no se puede deshacer**. La primera versión de este pin
//  se contaminó a sí misma entre dos de sus tests; de haberla dejado pasar habría puesto en rojo a
//  `DataWipeServiceTests.removeUserPreferenceKeys_clearsAllExpectedKeys` y a
//  `HandoverGroupsDomainTests.removeGroupsDomainPreferenceKeys_clearsBetaGateAndPerGroupPrefixes`,
//  que afirman `object(forKey:) == nil` de estas MISMAS keys sobre almacenes aislados — y el
//  dominio de registro se cuela igual en ellos. Sería este mismo bug movido de disco a memoria.
//  ⇒ el mecanismo se prueba con una key de SONDA que no lee nadie, y los seams reales con un doble.
//
//  Y AQUÍ VIVE TAMBIÉN EL LAVADO GENERAL, cerrado el 2026-08-05, porque es donde se destapó: el
//  seam efímero hace su parte bien y las dos keys de onboarding SEGUÍAN apareciendo en el plist del
//  contenedor. El culpable era `AppPreferences.loadFromDefaults`, que re-persistía lo que acababa de
//  leer — para un valor ya en disco, un no-op invisible; para uno del dominio volátil, un lavado.
//  El arreglo NO son dos guards en las dos properties del seam (los llevó unas horas y se quitaron a
//  propósito: un cinturón local dejaba al pin sin caer con el mutante): es `isLoadingFromDefaults`,
//  y con él **cargar no escribe**, ni al disco ni al canal de sync. Cuatro tests lo sostienen y
//  ninguno cubre a otro — la matriz por FORMA de carga, la recarga tras un wipe, la no-fuga del flag
//  hacia las migraciones del `init`, y los dos escáneres estructurales del final.
//

import Foundation
import Testing

@testable import Yala

@Suite("Seams de uitest · sin rastro en disco", .serialized)
@MainActor
struct UITestSeamPersistenceIsolationTests {

    // MARK: - Almacén de juguete

    /// Un `UserDefaults` real (no un fake) del que además conocemos el suite, porque el instrumento
    /// que carga el peso es `persistentDomain(forName:)`: es lo único que distingue «el valor está
    /// puesto» de «el valor está ESCRITO». `object(forKey:)` no sirve — devuelve igual lo registrado
    /// en el dominio volátil, que es precisamente lo que estos métodos usan.
    private struct ToyStore {
        let suite: String
        let defaults: UserDefaults

        /// Lo que quedaría en el plist si el proceso muriera ahora.
        func persisted(_ key: String) -> Any? { defaults.persistentDomain(forName: suite)?[key] }
    }

    private func makeToyStore() throws -> ToyStore {
        let suite = "test.uitest-seam.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return ToyStore(suite: suite, defaults: defaults)
    }

    /// Espía del mecanismo volátil: registra qué se habría puesto en memoria, sin ponerlo.
    private final class VolatileApplySpy {
        private(set) var applied: [String: Any] = [:]
        private(set) var calls = 0

        var function: UITestEphemeralDefaults.VolatileApply {
            { [self] _, values in
                calls += 1
                applied.merge(values) { _, new in new }
            }
        }

        func value(_ key: String) -> Bool? { applied[key] as? Bool }
    }

    // MARK: - Comportamiento · el mecanismo volátil (con key de SONDA)

    /// El mecanismo REAL, ejercitado contra una key que no lee nadie. Las tres aserciones son las
    /// tres cosas que hay que saber de él, y la tercera es la que obliga a que todo lo demás de
    /// este fichero use un doble.
    ///
    /// El instrumento se valida antes de usarlo: escribir de verdad TIENE que verse en
    /// `persistentDomain`. Un instrumento que devuelve `nil` para todo diría «no hay rastro» de
    /// cualquier cosa, y esta familia ya costó cuatro descartes falsos por creerle a uno sin
    /// comprobar que tocaba algo.
    @Test func elMecanismoVolatil_llegaALosLectores_noSeEscribe_yEsDelProceso() throws {
        let store = try makeToyStore()
        let otro = try makeToyStore()
        defer {
            store.defaults.removePersistentDomain(forName: store.suite)
            otro.defaults.removePersistentDomain(forName: otro.suite)
        }
        // Sufijo único: lo que se registra NO se puede desregistrar, así que la sonda no puede ser
        // una key que lea nadie más (ni siquiera otra corrida de este mismo test).
        let sonda = "uitest.ephemeral.probe.\(UUID().uuidString)"

        store.defaults.set(true, forKey: sonda)
        #expect(store.persisted(sonda) as? Bool == true, "Un `set` no se ve en el dominio persistente — el instrumento no mide nada.")
        store.defaults.removeObject(forKey: sonda)

        UITestEphemeralDefaults.liveVolatileApply(store.defaults, [sonda: true])

        #expect(store.defaults.bool(forKey: sonda) == true, "Lo aplicado no llega a los lectores — el seam no pondría nada.")
        #expect(store.persisted(sonda) == nil, "Lo aplicado quedó ESCRITO — el seam volvería a sobrevivir al proceso.")
        #expect(
            otro.defaults.bool(forKey: sonda) == true,
            """
            El dominio de registro resultó ser por INSTANCIA. Si algún día es cierto, el pin puede \
            dejar de inyectar el doble y ejercitar el mecanismo real con las keys de verdad.
            """
        )
    }

    // MARK: - Comportamiento · gate beta de Grupos

    /// Parte de un simulador YA contaminado, que es el estado en el que quedaron todos los que
    /// corrieron la versión anterior. La purga no es cinturón: es lo único que los cura, y además
    /// hace falta para que el valor volátil GANE (el dominio de registro tiene menos prioridad que
    /// el persistente).
    @Test func groupsBetaUnlocked_sePoneEnMemoriaYSeBorraDelDisco() throws {
        let store = try makeToyStore()
        defer { store.defaults.removePersistentDomain(forName: store.suite) }
        let key = AppPreferences.Keys.groupsBetaUnlocked
        let spy = VolatileApplySpy()

        store.defaults.set(true, forKey: key)

        UITestEphemeralDefaults.applyGroupsBetaUnlocked(to: store.defaults, volatileApply: spy.function)

        #expect(spy.value(key) == true, "El seam no dejó Grupos desbloqueado: los XCUI de Grupos chocarían con GroupsBetaGateView.")
        #expect(
            store.persisted(key) == nil,
            "«\(key)» sigue ESCRITA: el gate beta de Grupos queda desbloqueado para siempre en ese simulador, también en un arranque manual."
        )
    }

    // MARK: - Comportamiento · onboarding + Welcome Chooser

    @Test func onboardingSaltado_sePoneEnMemoriaYSeBorraDelDisco() throws {
        let store = try makeToyStore()
        defer { store.defaults.removePersistentDomain(forName: store.suite) }
        let keys = [AppPreferences.Keys.hasCompletedOnboarding, AppPreferences.Keys.hasShownWelcomeChooser]
        let spy = VolatileApplySpy()

        for key in keys { store.defaults.set(true, forKey: key) }

        UITestEphemeralDefaults.applyOnboardingAlreadySeen(true, to: store.defaults, volatileApply: spy.function)

        for key in keys {
            #expect(spy.value(key) == true, "«\(key)» no se puso en memoria — el XCUITest vería el onboarding.")
            #expect(
                store.persisted(key) == nil,
                "«\(key)» sigue ESCRITA: tras cualquier XCUITest, abrir la app a mano se salta onboarding y Welcome Chooser."
            )
        }
    }

    /// La rama que NO pone nada sigue purgando, y por eso va incondicional en el bootstrap: los
    /// launches que quieren VER el onboarding (`-uitest-onboarding`, `WelcomeChooserUITests`) son
    /// justo los que un simulador contaminado deja en verde falso.
    @Test func onboardingNoSaltado_purgaAunqueNoPongaNada() throws {
        let store = try makeToyStore()
        defer { store.defaults.removePersistentDomain(forName: store.suite) }
        let keys = [AppPreferences.Keys.hasCompletedOnboarding, AppPreferences.Keys.hasShownWelcomeChooser]
        let spy = VolatileApplySpy()

        for key in keys { store.defaults.set(true, forKey: key) }

        UITestEphemeralDefaults.applyOnboardingAlreadySeen(false, to: store.defaults, volatileApply: spy.function)

        #expect(spy.calls == 0, "La rama `seen: false` puso valores en memoria — un test de onboarding no vería el onboarding.")
        for key in keys {
            #expect(
                store.persisted(key) == nil,
                "«\(key)» sobrevivió a la purga: un simulador contaminado deja en verde falso a los tests que ejercitan el onboarding."
            )
        }
    }

    // MARK: - Comportamiento · el LAVADO del valor volátil

    /// `UserDefaults` que cuenta las escrituras por clave. Hace falta un contador y no una lectura
    /// del estado final porque lo que se juzga es «¿escribió?», y re-escribir el MISMO valor deja el
    /// store idéntico: sin contar, el mutante no cae.
    private final class CountingDefaults: UserDefaults {
        nonisolated(unsafe) var writes: [String: Int] = [:]

        override func set(_ value: Any?, forKey defaultName: String) {
            writes[defaultName, default: 0] += 1
            super.set(value, forKey: defaultName)
        }
    }

    /// El seam efímero NO basta por sí solo, y esto es lo que lo descubrió: medido en el simulador
    /// el 2026-08-05, con `applyOnboardingAlreadySeen` ya sin escribir nada, las dos keys SEGUÍAN
    /// apareciendo en el plist del contenedor tras un launch `-uitest`.
    ///
    /// El culpable es `AppPreferences.loadFromDefaults`, que **re-persistía lo que acababa de leer**:
    /// el default hardcoded es `false`, el store devuelve `true` —del dominio VOLÁTIL— y el `didSet`
    /// lo escribía de vuelta al persistente. Un **lavado**: lo efímero se vuelve permanente y el bug
    /// regresa entero. Es una clase de fallo que ningún test del seam puede ver, porque el seam hace
    /// su parte bien.
    ///
    /// Aquí se planta en el dominio PERSISTENTE en vez del volátil a propósito: el `didSet` no
    /// distingue de qué dominio vino el valor —esa es justo la razón de que el lavado exista— y el
    /// dominio de registro es del PROCESO y no se puede deshacer (§ cabecera), así que usarlo en un
    /// test envenenaría a las suites vecinas. El invariante que se juzga es el mismo: **cargar no
    /// escribe**.
    ///
    /// LA MATRIZ ES POR **FORMA DE CARGA**, NO POR PREFERENCIA, y ésa es la única manera de que sirva
    /// de algo: `loadFromDefaults` lee de siete maneras distintas (enum tras `if let`, `Int` tras
    /// `object != nil`, `Bool` incondicional, `String ?? ""`, listas por coma, listas por pipe,
    /// `loadBool(defaultIfMissing:)`) y cada una entra por un `persist*` distinto. Con la versión
    /// anterior —solo las dos keys de onboarding, las dos `Bool`— quitar el guard de `persistString`
    /// o de `persistInt` dejaba el test en VERDE. Verificado por mutación, no por inspección.
    ///
    /// Y por eso también se contabiliza el **tráfico de sync** sin poder espiarlo: `PreferenceSyncService`
    /// es un singleton con `local` hardcodeado a `.standard`, así que un contador sobre el store
    /// inyectado no ve el push. Lo que lo cubre es que ambas cosas están detrás del MISMO guard,
    /// dentro del mismo helper — y eso lo fija `losTresPersistLlevanElGuardYSonElUnicoPushDeAquí`.
    @Test func cargarPreferencias_noReescribeLoQueYaDiceElStore() throws {
        let suite = "test.uitest-seam.lavado.\(UUID().uuidString)"
        let counting = try #require(CountingDefaults(suiteName: suite))
        defer { counting.removePersistentDomain(forName: suite) }

        // Los centinelas de las tres migraciones del `init`. Corren FUERA de `loadFromDefaults` y SÍ
        // deben escribir (por eso hay un test dedicado a que el flag no se les filtre), así que aquí
        // se desactivan o su ruido entra en el conteo. `PanelPreferencesMigration` además consulta el
        // `NSUbiquitousKeyValueStore` REAL del proceso cuando corre: sin plantar su centinela, el
        // número de escrituras dependería de estado global y el test sería flaky por el entorno.
        for centinela in [
            AppPreferences.Keys.aiInsightsMigratedV1,
            AppPreferences.Keys.aiTogglesRemovedV2,
            AppPreferences.Keys.panelPrefsMigratedV2,
        ] {
            counting.set(true, forKey: centinela)
        }

        // Valor plantado ≠ default hardcoded en TODAS: si coincidieran, el `guard oldValue != nuevo`
        // cortaría solo y el test pasaría sin ejercitar el arreglo.
        let plantadas: [(key: String, valor: Any, forma: String)] = [
            (AppPreferences.Keys.hasCompletedOnboarding, true, "Bool incondicional — la key del seam"),
            (AppPreferences.Keys.hasShownWelcomeChooser, true, "Bool incondicional — la otra key del seam"),
            (AppPreferences.Keys.defaultCurrencyCode, "USD", "enum String tras `if let` + parse"),
            (AppPreferences.Keys.usageFocus, "groupsOnly", "enum String con fallback incondicional (reset-on-absent)"),
            (AppPreferences.Keys.userProfileIcon, "star", "String con `?? \"\"` incondicional"),
            (AppPreferences.Keys.decimalPlaces, 4, "Int tras `object != nil`"),
            (AppPreferences.Keys.firstWeekday, 1, "Int con rawValue (`.sunday`)"),
            (AppPreferences.Keys.colorfulIcons, false, "Bool con default hardcoded TRUE"),
            (AppPreferences.Keys.panelAccountsCollapsed, false, "Bool por `loadBool(defaultIfMissing: true)`"),
            (AppPreferences.Keys.budgetAlertsEnabled, true, "Bool SYNCED, lectura incondicional"),
            (AppPreferences.Keys.expensesOnlyMode, true, "Bool SYNCED con dos rutas de entrada"),
            (AppPreferences.Keys.secondaryCurrencies, "USD,EUR", "lista serializada por COMA"),
            (AppPreferences.Keys.accountsSortOrderNames, "Cash|Bank", "lista serializada por PIPE"),
            (AppPreferences.Keys.panelTendenciasOrder, "a,b", "lista por `parseList`"),
        ]
        for p in plantadas { counting.set(p.valor, forKey: p.key) }
        counting.writes = [:]

        let prefs = AppPreferences(defaults: counting)

        // LLEGADA ANTES QUE EL CERO. Un rawValue que no parsea no asigna, el `didSet` no corre y el
        // contador daría 0 sin haber ejercitado nada — la familia de «Executed 0 tests». Cada
        // aserción de aquí es la que hace que su cero signifique algo.
        #expect(prefs.hasCompletedOnboarding == true)
        #expect(prefs.hasShownWelcomeChooser == true)
        #expect(prefs.defaultCurrencyCode == .usd)
        #expect(prefs.usageFocus == .groupsOnly)
        #expect(prefs.userProfileIcon == "star")
        #expect(prefs.decimalPlaces == 4)
        #expect(prefs.firstWeekday == .sunday)
        #expect(prefs.colorfulIcons == false)
        #expect(prefs.panelAccountsCollapsed == false)
        #expect(prefs.budgetAlertsEnabled == true)
        #expect(prefs.expensesOnlyMode == true)
        #expect(prefs.secondaryCurrencies == ["USD", "EUR"])
        #expect(prefs.accountsSortOrderNames == ["Cash", "Bank"])
        #expect(prefs.panelTendenciasOrder == ["a", "b"])

        for p in plantadas {
            #expect(
                counting.writes[p.key, default: 0] == 0,
                """
                `AppPreferences` re-escribió «\(p.key)» al cargarla (\(counting.writes[p.key, default: 0]) veces) \
                — forma de carga: \(p.forma). Sobre un valor VOLÁTIL eso es un lavado: lo convierte en \
                persistente y devuelve el bug de «tras un XCUITest, abrir Yala Dev a mano se salta onboarding \
                y Welcome Chooser». Y sobre una key `synced: true` es además un push a iKV/outbox por \
                lanzamiento, con el eco de HLC fresco que eso arrastra en Modo Nube.
                """
            )
        }

        // CONTROL POSITIVO. Sin él, un `persist*` roto del todo —o un `defer` que no restaura el
        // flag— dejaría todos los ceros de arriba en verde sin persistir absolutamente nada.
        prefs.hasSeenSettingsTour = true
        #expect(
            counting.writes[AppPreferences.Keys.hasSeenSettingsTour, default: 0] == 1,
            "Asignar una preferencia ya no la escribe: el guard de carga se quedó puesto (¿falta el `defer`?) y AppPreferences no persiste nada."
        )
    }

    /// La otra dirección del mismo bug, y la que se lleva un daño de USUARIO: `DataWipeService`
    /// borra la key, el observer dispara una recarga, el mirror cae a su default y —antes— el
    /// `didSet` la RE-MATERIALIZABA con ese default y lo empujaba a iKV. Cinco propiedades
    /// `synced: true` se leen sin guard de presencia, así que el wipe quedaba a medias y encima
    /// propagaba el reset. `OnboardingView` describe por escrito esa contaminación («A standalone
    /// `expensesOnlyMode` key is contamination from didSet side-effects»).
    ///
    /// Se ejercita el camino REAL (notificación → observer), no una llamada directa: el `init` ya lo
    /// cubre el test de arriba, y lo que aquí importa es la recarga, que es por donde entra el eco.
    @Test func recargaTrasUnWipe_noReMaterializaLaKeyBorrada() async throws {
        let suite = "test.uitest-seam.wipe.\(UUID().uuidString)"
        let counting = try #require(CountingDefaults(suiteName: suite))
        defer { counting.removePersistentDomain(forName: suite) }
        let key = AppPreferences.Keys.expensesOnlyMode

        for centinela in [
            AppPreferences.Keys.aiInsightsMigratedV1,
            AppPreferences.Keys.aiTogglesRemovedV2,
            AppPreferences.Keys.panelPrefsMigratedV2,
        ] {
            counting.set(true, forKey: centinela)
        }
        counting.set(true, forKey: key)

        let prefs = AppPreferences(defaults: counting)
        try #require(prefs.expensesOnlyMode == true, "El mirror no cargó el valor: el wipe de abajo no tendría nada que revertir.")

        counting.removeObject(forKey: key)  // ← lo que hace `DataWipeService.removeUserPreferenceKeys`
        counting.writes = [:]
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: counting)

        // Esperar al POSITIVO (el observer salta a MainActor por `Task`), nunca al cero: sin esto se
        // estaría aserjando sobre una recarga que quizá no ha ocurrido todavía.
        var vueltas = 0
        while prefs.expensesOnlyMode && vueltas < 200 {
            try await Task.sleep(for: .milliseconds(5))
            vueltas += 1
        }
        try #require(prefs.expensesOnlyMode == false, "El observer no recargó en 1 s — el instrumento no tocó nada y los ceros de abajo no miden.")

        #expect(
            counting.writes[key, default: 0] == 0,
            "La recarga re-escribió «\(key)» (\(counting.writes[key, default: 0]) veces) con su default tras el wipe, y por ser `synced: true` lo empujó además a iKV/outbox."
        )
        #expect(
            counting.object(forKey: key) == nil,
            "«\(key)» volvió a existir tras el wipe: el borrado queda a medias y la detección de instalación fresca de `OnboardingView` lee una key que nadie escribió a propósito."
        )
    }

    /// El riesgo que introduce el flag, hecho aserción. `isLoadingFromDefaults` es un MODO: si
    /// alguien lo mueve para cubrir el `init` entero, las tres migraciones de `:826-855` dejan de
    /// grabar, corren en CADA arranque y **ningún otro test de este fichero se entera**.
    ///
    /// El escenario es el de `aiTogglesRemovedV2`: consent aceptado + toggle apagado ⇒ revoca el
    /// consent. La aserción que carga el peso es la del dominio PERSISTENTE, no la de memoria: con
    /// el flag filtrado, la property queda en `false` y el store se queda en `true`.
    @Test func elFlagDeCarga_noSeFiltraALasMigracionesDelInit() throws {
        let store = try makeToyStore()
        defer { store.defaults.removePersistentDomain(forName: store.suite) }
        let consent = AppPreferences.Keys.aiInsightsConsentAccepted

        store.defaults.set(true, forKey: AppPreferences.Keys.aiInsightsMigratedV1)  // la OTRA migración, fuera
        store.defaults.set(true, forKey: AppPreferences.Keys.panelPrefsMigratedV2)
        store.defaults.set(true, forKey: consent)
        store.defaults.set(false, forKey: AppPreferences.Keys.aiInsightsEnabled)

        let prefs = AppPreferences(defaults: store.defaults)

        #expect(prefs.aiInsightsConsentAccepted == false, "La migración `aiTogglesRemovedV2` no revocó el consent en memoria.")
        #expect(
            store.persisted(consent) as? Bool == false,
            """
            El consent revocado NO quedó ESCRITO: `isLoadingFromDefaults` se filtró más allá de \
            `loadFromDefaults` y las migraciones del `init` dejaron de persistir. Corren en cada \
            arranque y todo lo demás sigue en verde.
            """
        )
        #expect(
            store.persisted(AppPreferences.Keys.aiTogglesRemovedV2) as? Bool == true,
            "El centinela de la migración no se escribió — misma fuga, vista desde el `defaults.set` directo."
        )
    }

    // MARK: - Comportamiento · centinela del seed de categorías

    /// Este seam no puede ser efímero —lo escribe código de PRODUCCIÓN y tiene que sobrevivir entre
    /// lanzamientos— así que la mitad que impide volver a ensuciar es el NAMESPACING por store. Sin
    /// él, una corrida uitest deja el centinela del store personal puesto con el store personal
    /// vacío, y ese arranque manual se queda sin categorías.
    @Test func centinelaDelSeed_esUnaKeyDistintaPorStore() {
        #expect(
            CategorySeedSentinel.key(isUITest: true) != CategorySeedSentinel.key(isUITest: false),
            "El store uitest y el personal comparten centinela: el early-return de uno decide por el otro."
        )
        #expect(CategorySeedSentinel.key(isUITest: false) == CategorySeedSentinel.productionKey)
        #expect(CategorySeedSentinel.key(isUITest: true) == CategorySeedSentinel.uiTestKey)
        #expect(
            Set(CategorySeedSentinel.allKeys) == [CategorySeedSentinel.productionKey, CategorySeedSentinel.uiTestKey],
            "`allKeys` no cubre las dos: el barrido del wipe dejaría una viva."
        )
        // El host de unit tests NO lleva `-uitest` (es lo que hace inalcanzable el call site real y
        // obliga al source-scan de abajo). Afirmarlo aquí deja escrito a qué store apunta este host.
        #expect(CategorySeedSentinel.currentKey == CategorySeedSentinel.productionKey)
    }

    @Test func purgaDelCentinela_borraElDeProduccionYRespetaElDeUITest() throws {
        let store = try makeToyStore()
        defer { store.defaults.removePersistentDomain(forName: store.suite) }

        store.defaults.set(true, forKey: CategorySeedSentinel.productionKey)
        store.defaults.set(true, forKey: CategorySeedSentinel.uiTestKey)

        UITestEphemeralDefaults.purgeCategorySeedSentinel(from: store.defaults)

        #expect(
            store.persisted(CategorySeedSentinel.productionKey) == nil,
            "El centinela de PRODUCCIÓN sobrevivió: el arranque manual siguiente hará early-return con el store vacío y se quedará sin categorías."
        )
        #expect(
            store.persisted(CategorySeedSentinel.uiTestKey) as? Bool == true,
            "La purga se llevó también el centinela del store uitest — no es lo que contamina y borrarlo solo añade trabajo por launch."
        )
    }

    /// El barrido REAL del wipe, con almacén inyectado. Sin la key uitest en la lista, un
    /// `-uitest-reset` dejaría su centinela puesto y el seed del perfil no crearía categorías.
    ///
    /// Las dos keys van NOMBRADAS, no iteradas desde `allKeys`: medido por mutación —encogiendo
    /// `allKeys` a solo la de producción, la versión que iteraba seguía en VERDE porque plantaba y
    /// comprobaba exactamente lo que el barrido había reducido. Un test que se alimenta de la misma
    /// lista que juzga comprueba que la lista es coherente consigo misma, no que esté completa.
    @Test func elBarridoDelWipeBorraLasDosKeysDelCentinela() throws {
        let store = try makeToyStore()
        defer { store.defaults.removePersistentDomain(forName: store.suite) }
        let keys = [CategorySeedSentinel.productionKey, CategorySeedSentinel.uiTestKey]

        for key in keys { store.defaults.set(true, forKey: key) }

        DataWipeService.removeUserPreferenceKeys(from: store.defaults)

        for key in keys {
            #expect(
                store.defaults.object(forKey: key) == nil,
                "El wipe dejó «\(key)» viva: tras un `-uitest-reset` el seed del perfil haría early-return y la corrida arrancaría sin categorías."
            )
        }
    }

    // MARK: - Cableado (source-scan)

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Código sin las líneas de comentario: el porqué de cada seam se explica AHÍ nombrando estas
    /// mismas keys y estos mismos métodos, y contar prosa haría que documentar el invariante lo
    /// rompiera (a `UITestProTierIsolationTests` le pasó a la primera).
    private func code(at relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El CUERPO de una función, delimitado por llaves. Acotar es load-bearing en los dos escáneres
    /// que lo usan, y vale la lección de `TestProcessGuardTests`: un rango demasiado ancho comprueba
    /// que el símbolo EXISTE, no que alguien lo llame. Sobre `AppBootstrapper.swift` entero,
    /// `groupsBetaUnlocked` aparece también en `persistBackendInviteIntent` —producción, tiene que
    /// seguir escribiendo la key—; sobre `AppPreferences.swift` entero, un `guard` suelto en
    /// cualquier sitio contaría igual que uno dentro del helper.
    private func body(ofFunc signature: String, in source: String) throws -> String {
        let found = try #require(
            source.range(of: signature),
            "El escáner no encontró `\(signature)` — se movió o se renombró, y este test dejó de comprobar nada."
        )
        let rest = source[found.upperBound...]
        let open = try #require(rest.firstIndex(of: "{"), "`\(signature)` sin cuerpo.")

        var depth = 0
        var close: String.Index?
        var index = open
        while index < rest.endIndex {
            switch rest[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { close = index }
            default: break
            }
            if close != nil { break }
            index = rest.index(after: index)
        }
        let end = try #require(close, "Llaves desbalanceadas al acotar `\(signature)`.")
        return String(rest[open...end])
    }

    private func hookBody() throws -> String {
        let body = try body(ofFunc: "func applyUITestHooksEarly", in: code(at: "Yala/App/AppBootstrapper.swift"))

        // Un corte que no capturó nada devolvería «cero apariciones» y PARECERÍA una medición: es la
        // misma familia que «Executed 0 tests». Estas dos anclas son código que vive dentro del
        // cuerpo y fuera de lo que este test comprueba.
        try #require(body.contains("UITestHooks.shouldReset"), "El corte del cuerpo salió vacío o mal delimitado.")
        try #require(body.contains("applyUITestProTier("), "El corte del cuerpo no llegó al seam de Pro — está mal delimitado.")
        return body
    }

    /// Los conteos no son decoración: sin ellos, un método renombrado dejaría al escáner sin
    /// encontrar nada y la suite pasaría en verde sin comprobar absolutamente nada.
    @Test func elBootstrapCablaLosTresSeams_yNoEscribeNingunaKeyAMano() throws {
        let body = try hookBody()

        let llamadas = [
            "UITestEphemeralDefaults.applyGroupsBetaUnlocked(",
            "UITestEphemeralDefaults.applyOnboardingAlreadySeen(",
            "UITestEphemeralDefaults.purgeCategorySeedSentinel(",
        ]
        for llamada in llamadas {
            let veces = body.components(separatedBy: llamada).count - 1
            #expect(veces == 1, "Se esperaba exactamente 1 llamada a `\(llamada)` en el cuerpo del hook, hay \(veces).")
        }

        // La otra cara: el cuerpo no puede NOMBRAR las keys. Es más fuerte que buscar un `set(...)`
        // concreto —cubre también un `@AppStorage`, un helper nuevo o un literal— y es exactamente
        // lo que estaba escrito antes del fix.
        let prohibidas = [
            (AppPreferences.Keys.groupsBetaUnlocked, "el gate beta de Grupos queda desbloqueado para siempre en ese simulador"),
            (AppPreferences.Keys.hasCompletedOnboarding, "abrir la app a mano tras un XCUITest se salta el onboarding"),
            (AppPreferences.Keys.hasShownWelcomeChooser, "abrir la app a mano tras un XCUITest se salta el Welcome Chooser"),
            (CategorySeedSentinel.productionKey, "el arranque manual siguiente se queda sin categorías"),
        ]
        for (key, consecuencia) in prohibidas {
            let veces = body.components(separatedBy: key).count - 1
            #expect(
                veces == 0,
                """
                `applyUITestHooksEarly` vuelve a nombrar «\(key)» (\(veces) veces). Si la escribe, \
                PERSISTE en un almacén que sobrevive al proceso y \(consecuencia). Va por \
                `UITestEphemeralDefaults`, que aplica en memoria y purga el disco.
                """
            )
        }

        // El hueco que dejaría un doble inyectado en PRODUCCIÓN: los tests de comportamiento pasan
        // un espía, así que un `volatileApply:` no-op cableado aquí los dejaría a todos en verde
        // con el seam sin aplicar nada.
        #expect(
            !body.contains("volatileApply"),
            "El bootstrap le pasa un `volatileApply` propio al seam: el mecanismo real dejaría de ejecutarse y ningún test de comportamiento lo notaría."
        )
    }

    /// El otro extremo del mismo hueco: que el DEFAULT de los seams sea el mecanismo real. Cambiarlo
    /// por un no-op no rompe ni un solo test de comportamiento —todos inyectan— y deja los XCUITest
    /// arrancando con onboarding y con el gate beta puesto.
    @Test func losSeamsPorDefectoUsanElMecanismoReal() throws {
        let source = try code(at: "Yala/App/UITestEphemeralDefaults.swift")

        let porDefecto = source.components(separatedBy: "volatileApply: VolatileApply = liveVolatileApply").count - 1
        #expect(
            porDefecto == 2,
            """
            Se esperaban 2 seams con `liveVolatileApply` por defecto (gate beta y onboarding) y hay \(porDefecto). \
            O se renombró el mecanismo, o alguno dejó de usarlo: en los dos casos el pin dejó de comprobar nada.
            """
        )
        let registros = source.components(separatedBy: "register(defaults:").count - 1
        #expect(
            registros == 1,
            "`register(defaults:)` aparece \(registros) veces y solo debe estar dentro de `liveVolatileApply` — es el único punto por el que pasa el mecanismo."
        )
    }

    /// La mitad estructural del arreglo del LAVADO, y es la que hace honesto al test de conteo.
    ///
    /// El contador vive en el `UserDefaults` inyectado, así que ve `defaults.set` y **no ve el push**
    /// a `PreferenceSyncService` —singleton con `local` hardcodeado a `.standard` (`:78`), no
    /// espiable sin refactorear sus ~20 construcciones—. Que contar escrituras cubra TAMBIÉN la mitad
    /// de tráfico depende por completo de que las dos cosas vivan detrás del MISMO guard y dentro del
    /// MISMO helper. Eso no es una propiedad que un test de comportamiento pueda observar: es
    /// estructura, y va por escáner.
    ///
    /// El mutante que lo justifica: dejar el push FUERA del guard
    /// (`guard !isLoadingFromDefaults else { if synced { … } ; return }`) deja los tests de conteo en
    /// VERDE con la mitad de sync entera sin arreglar.
    @Test func losTresPersistLlevanElGuardYSonElUnicoPushDeAqui() throws {
        let source = try code(at: "Yala/App/Services/AppPreferences.swift")
        let helpers = ["func persistString(", "func persistBool(", "func persistInt("]

        for helper in helpers {
            let cuerpo = try body(ofFunc: helper, in: source)
            try #require(cuerpo.contains("defaults.set("), "El corte de `\(helper)` salió vacío o mal delimitado.")
            #expect(
                cuerpo.contains("guard !isLoadingFromDefaults else { return }"),
                """
                `\(helper)` perdió el guard de carga: `loadFromDefaults` vuelve a escribir por esa vía. \
                Sobre un valor volátil es el lavado del seam de onboarding; sobre una key `synced: true`, \
                un push a iKV/outbox en cada lanzamiento.
                """
            )
        }

        // Y que el push NO viva en ningún otro sitio de este fichero. Si alguien lo saca del helper
        // —a un `didSet`, a un método nuevo— el contador deja de cubrirlo y nadie se entera.
        let pushesTotales = source.components(separatedBy: "PreferenceSyncService.shared.set(").count - 1
        let pushesEnHelpers = try helpers.reduce(0) { total, helper in
            try total + (body(ofFunc: helper, in: source)
                .components(separatedBy: "PreferenceSyncService.shared.set(").count - 1)
        }
        #expect(pushesEnHelpers == 3, "Se esperaba 1 push por helper y hay \(pushesEnHelpers) en total dentro de los tres.")
        #expect(
            pushesTotales == pushesEnHelpers,
            """
            `AppPreferences` empuja a `PreferenceSyncService` desde \(pushesTotales - pushesEnHelpers) sitio(s) \
            fuera de `persist*`. Ese push no está detrás del guard de carga y el test que cuenta escrituras \
            en el store inyectado no puede verlo.
            """
        )
    }

    /// El puente que el arreglo CORTÓ, pagado en su punto de intención. Hasta el 2026-08-05 estas dos
    /// preferencias llegaban a iCloud de rebote —escribían `UserDefaults` en crudo y
    /// `AppPreferences.loadFromDefaults` re-persistía lo que releía, empujándolas al canal—. Al dejar
    /// de re-persistir, ese puente desaparece: sin este cableado, activar las alertas de presupuesto
    /// desde el primer de notificaciones o el modo «solo gastos» desde Ajustes queda LOCAL para
    /// siempre, sin un solo rojo y sin nada visible en la app.
    ///
    /// Es un escáner y no un test de comportamiento porque el fallo es una AUSENCIA: revertir el
    /// cableado no rompe ninguna aserción observable desde un unit test —el valor sigue llegando a
    /// `UserDefaults`, que es lo que leen los consumidores locales— y lo único que cambia es que
    /// nunca sale del dispositivo. Eso solo lo probaría un e2e con dos devices.
    @Test func losDosPuntosDeIntencionPublicanSuPreferencia() throws {
        // `simbolo` es cómo se NOMBRA la key en el call-site, no su valor: el escáner lee código
        // fuente, así que comparar contra el literal de `Keys` no serviría de nada si el call-site
        // usa la constante (que es lo que debe usar).
        let casos: [(fichero: String, simbolo: String, consecuencia: String)] = [
            (
                "Yala/App/Views/Notifications/NotificationPrimerSheet.swift",
                "AppPreferences.Keys.budgetAlertsEnabled",
                "activar las notificaciones desde el primer sheet deja de propagar las alertas de presupuesto a los otros devices"
            ),
            (
                "Yala/App/Views/Settings/PersonalizationSettingsView.swift",
                "AppPreferences.Keys.expensesOnlyMode",
                "el toggle de «solo gastos» de Ajustes deja de propagar, mientras el de onboarding sigue haciéndolo ⇒ sincroniza a veces sí y a veces no, que es el peor síntoma posible"
            ),
        ]

        for caso in casos {
            let source = try code(at: caso.fichero)
            let pushes = source.components(separatedBy: "PreferenceSyncService.shared.set(").count - 1
            #expect(
                pushes == 1,
                """
                \(caso.fichero) tiene \(pushes) llamadas a `PreferenceSyncService.shared.set(` y debe tener 1: \
                sin ella \(caso.consecuencia). El mirror ya no publica por nadie — ver el docblock de \
                `AppPreferences.loadFromDefaults`.
                """
            )
            #expect(
                source.contains(caso.simbolo),
                "\(caso.fichero) ya no nombra `\(caso.simbolo)`: publica, pero quizá otra preferencia."
            )
        }
    }

    /// El centinela del seed no tiene una mitad efímera que lo proteja: lo único que impide que una
    /// corrida uitest escriba la key de producción es que TODOS los call sites pasen por
    /// `CategorySeedSentinel`. Uno solo que se salte el namespace reabre el agujero entero, así que
    /// el criterio se fija sobre `Yala/` en vez de enumerar sitios.
    @Test func ningunCallSiteUsaElLiteralDelCentinela() throws {
        let appDir = repoRoot.appending(path: "Yala")
        let files = (FileManager.default.enumerator(at: appDir, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? [])

        // Antes de leer un cero como señal, comprobar que el instrumento tocó algo.
        #expect(files.count >= 500, "El escáner solo encontró \(files.count) ficheros bajo `Yala/` — no está midiendo el árbol real.")

        var conLiteral: [String] = []
        for url in files {
            let code = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            if code.contains("\"\(CategorySeedSentinel.productionKey)\"") { conLiteral.append(url.lastPathComponent) }
        }

        #expect(
            conLiteral == ["CategorySeed.swift"],
            """
            El literal «\(CategorySeedSentinel.productionKey)» aparece en \(conLiteral.joined(separator: ", ")) y solo \
            debe existir en la declaración de `CategorySeedSentinel` (CategorySeed.swift). Un call site con el literal \
            suelto lee o escribe el centinela del OTRO store: bajo `-uitest` los datos viven en \
            `YalaModel-UITest` y `UserDefaults.standard` es el mismo almacén, así que la corrida deja el centinela \
            personal puesto y el arranque manual siguiente se queda sin categorías.
            """
        )

        // Y que el seed lo consuma por el namespace, no que el enum exista y nadie lo use.
        let seed = try code(at: "Yala/Seed/CategorySeed.swift")
        #expect(
            seed.contains("CategorySeedSentinel.currentKey"),
            "`seedCategoriesIfNeeded` ya no resuelve el centinela por `CategorySeedSentinel.currentKey`."
        )
    }
}

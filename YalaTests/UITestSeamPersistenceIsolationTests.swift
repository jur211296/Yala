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
    /// El culpable es `AppPreferences.loadFromDefaults`, que **re-persiste lo que acaba de leer**:
    /// el default hardcoded es `false`, el store devuelve `true` —del dominio VOLÁTIL— y el `didSet`
    /// lo escribe de vuelta al persistente. Un **lavado**: lo efímero se vuelve permanente y el bug
    /// regresa entero. Es una clase de fallo que ningún test del seam puede ver, porque el seam hace
    /// su parte bien.
    ///
    /// Aquí se planta en el dominio PERSISTENTE en vez del volátil a propósito: el `didSet` no
    /// distingue de qué dominio vino el valor —esa es justo la razón de que el lavado exista— y el
    /// dominio de registro es del PROCESO y no se puede deshacer (§ cabecera), así que usarlo en un
    /// test envenenaría a las suites vecinas. El invariante que se juzga es el mismo: **cargar no
    /// escribe**.
    @Test func cargarPreferencias_noReescribeLoQueYaDiceElStore() throws {
        let suite = "test.uitest-seam.lavado.\(UUID().uuidString)"
        let counting = try #require(CountingDefaults(suiteName: suite))
        defer { counting.removePersistentDomain(forName: suite) }
        let keys = [AppPreferences.Keys.hasCompletedOnboarding, AppPreferences.Keys.hasShownWelcomeChooser]

        for key in keys { counting.set(true, forKey: key) }
        counting.writes = [:]

        _ = AppPreferences(defaults: counting)

        for key in keys {
            #expect(
                counting.writes[key, default: 0] == 0,
                """
                `AppPreferences` re-escribió «\(key)» al cargarla (\(counting.writes[key, default: 0]) veces). \
                Sobre un valor VOLÁTIL eso es un lavado: lo convierte en persistente y devuelve el bug de \
                «tras un XCUITest, abrir Yala Dev a mano se salta onboarding y Welcome Chooser».
                """
            )
        }
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

    /// El CUERPO de `applyUITestHooksEarly`, delimitado por llaves. Acotar es load-bearing: sobre el
    /// fichero entero, `groupsBetaUnlocked` aparece también en `persistBackendInviteIntent`, que es
    /// producción y tiene que seguir escribiendo la key.
    private func hookBody() throws -> String {
        let source = try code(at: "Yala/App/AppBootstrapper.swift")
        let signature = try #require(
            source.range(of: "func applyUITestHooksEarly"),
            "El escáner no encontró `applyUITestHooksEarly` — se movió o se renombró, y este test dejó de comprobar nada."
        )
        let rest = source[signature.upperBound...]
        let open = try #require(rest.firstIndex(of: "{"), "`applyUITestHooksEarly` sin cuerpo.")

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
        let end = try #require(close, "Llaves desbalanceadas al acotar `applyUITestHooksEarly`.")
        let body = String(rest[open...end])

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

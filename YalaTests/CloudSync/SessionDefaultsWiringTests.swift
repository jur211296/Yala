//
//  SessionDefaultsWiringTests.swift
//  YalaTests / CloudSync
//
//  **El cableado de la puerta de dominio (M1, F3): quién la consulta y quién NO puede saltársela.**
//
//  Molde de `OwnerKeyValueWiringTests` y `AttestWiringTests`, y por el mismo motivo que ellos: lo que
//  se verifica aquí **no es una decisión, es un CALL-SITE**. `SessionDefaults` puede ser perfecta y sus
//  22 tests estar en verde mientras ningún consumidor la llama — que es exactamente el estado en el
//  que quedó el árbol al final de F1, con todo verde y la frontera abierta. Un test de comportamiento
//  no lo ve: `AppPreferences(defaults:)` es inyectable, así que un test que le pase el cajón a mano
//  pasa igual con el constructor de producción apuntando a `.standard`.
//
//  **El conteo esperado por consumidor es obligatorio.** Sin él, un escáner roto o una clase renombrada
//  pasarían en verde sin comprobar nada — la familia de «Executed 0 tests». Es la lección que
//  `AttestWiringTests` lleva escrita desde el 401 del 2026-07-31.
//

import Foundation
import Testing

@testable import Yala

private let repo: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

/// El código de un fichero SIN comentarios de línea: estos ficheros explican sus invariantes en prosa
/// y nombran los símbolos al hacerlo. Contar la prosa haría que documentar un invariante lo rompiera
/// — pasó ya en este repo con el escáner de los seams de `-uitest`.
private func code(_ path: String) -> String {
    let url = repo.appendingPathComponent(path)
    guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return "" }
    return raw.split(separator: "\n", omittingEmptySubsequences: false)
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        .joined(separator: "\n")
}

/// El cuerpo de una función, acotado de su firma al primer cierre a su nivel de indentación. Un rango
/// ancho comprueba que el símbolo EXISTE, no que alguien lo llame — la trampa de `TestProcessGuardTests`.
private func body(of signature: String, in path: String, closing: String = "\n    }\n") -> String {
    let parts = code(path).components(separatedBy: signature)
    guard parts.count >= 2 else { return "" }
    return parts[1].components(separatedBy: closing)[0]
}

enum SessionDefaultsScan {
    /// Todos los `.swift` bajo `Yala/`, como rutas relativas al repo.
    static func allSwiftFiles() -> [String] {
        let base = repo.appendingPathComponent("Yala")
        guard let e = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return [] }
        return e.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .map { $0.path.replacingOccurrences(of: repo.path + "/", with: "") }
    }
}

@Suite("SessionDefaults · cableado de los consumidores (source-scan)")
struct SessionDefaultsWiringTests {

    /// Los ficheros que este escáner lee. Declarados una vez para que el control del instrumento
    /// pueda comprobarlos TODOS — incluidos los que solo aparecen en una aserción.
    static let scannedFiles = [
        "Yala/App/AppBootstrapper.swift",
        "Yala/App/Services/PreferenceSyncService.swift",
        "Yala/App/YalaApp.swift",
        "Yala/Utils/DataWipeService.swift",
        "Yala/Utils/L10n.swift",
        "Yala/App/Models/SessionState.swift",
        "Yala/App/Views/Shared/YalaFormatterStatic.swift",
        "Yala/App/Views/Groups/FullModeActivationView.swift",
    ]

    static let appStorageFiles = [
        "Yala/App/ContentView.swift",
        "Yala/App/Theme/ViewModifiers.swift",
        "Yala/App/Views/Shared/ContextualGuideBanner.swift",
    ]

    // MARK: 0 · El control del instrumento

    /// **Sin esto, todo lo de abajo puede pasar VACUAMENTE y no es hipotético: pasó al escribirlo.**
    /// La aserción de `FullModeActivationView` estaba apuntando a `Views/Onboarding/` cuando el fichero
    /// vive en `Views/Groups/`; `code()` devolvía cadena vacía, el `!contains("UserDefaults.standard")`
    /// se cumplía trivialmente y el test salía VERDE sobre un fichero que no existe. Es la familia de
    /// «Executed 0 tests» y de la sonda que mide sin tocar nada: antes de leer un negativo como señal,
    /// comprueba que el instrumento tocó algo.
    @Test("todo fichero escaneado existe y tiene contenido")
    func everyScannedFileIsReadable() {
        for path in Self.scannedFiles + Self.appStorageFiles {
            let text = code(path)
            #expect(!text.isEmpty, "el escáner no puede leer `\(path)` — ¿se movió o se renombró?")
        }
    }

    // MARK: 1 · AppPreferences

    @Test("el ÚNICO constructor de producción de `AppPreferences` pasa por la puerta")
    func appPreferencesIsWired() {
        let src = code("Yala/App/AppBootstrapper.swift")
        #expect(src.contains("AppPreferences(defaults: SessionDefaults.current)"),
                """
                `AppBootstrapper` construye `AppPreferences` sin la puerta ⇒ la visita lee y escribe \
                las 76 properties en el dominio del DUEÑO
                """)
        #expect(!src.contains("AppPreferences()"),
                "queda un `AppPreferences()` con el default `.standard` en el bootstrap")
    }

    // MARK: 2 · PreferenceSyncService

    @Test("el espejo local se resuelve POR LLAMADA, nunca capturado en un `let`")
    func preferenceSyncResolvesPerCall() {
        // La razón es la ventana de entrada (ver la cláusula 2 del contrato): el descriptor se activa
        // con el proceso del dueño VIVO, y `PreferenceSyncService` es un singleton construido mucho
        // antes. Un `let local = SessionDefaults.current` capturaría el dominio del dueño para toda la
        // vida del proceso y el consentimiento RGPD de la invitada caería ahí.
        let src = code("Yala/App/Services/PreferenceSyncService.swift")
        #expect(!src.contains("private let local = UserDefaults.standard"),
                "`local` sigue clavado a `.standard`")
        #expect(!src.contains("private let local = SessionDefaults.current"),
                "`local` CAPTURA el dominio: es el mutante que la cláusula 2 prohíbe")
        #expect(src.contains("private var local: UserDefaults { SessionDefaults.current }"),
                "`local` tiene que ser una computed property que resuelva en cada acceso")
    }

    // MARK: 3 · Los @AppStorage

    @Test("la raíz de la app fija el store por defecto de TODOS los `@AppStorage`")
    func appStorageDefaultIsWired() {
        // `defaultAppStorage(_:)` daba CERO ocurrencias en el repo antes de F3: un modificador en la
        // raíz cubre los 11 sitios sin tocar ninguno, y los congela al arranque, que es justo lo que
        // la cláusula 3 pide (un `@AppStorage` reactivo produciría el brick del Welcome).
        let src = code("Yala/App/YalaApp.swift")
        #expect(src.contains(".defaultAppStorage(SessionDefaults.current)"),
                "la raíz no fija el store: los `@AppStorage` siguen leyendo el dominio del dueño")
    }

    @Test("los `@AppStorage` siguen siendo los 11 medidos — uno nuevo obliga a re-decidir")
    func appStorageCountIsPinned() {
        // DOS grafías, como en el inventario de F2: el atributo, y la construcción MANUAL del banner
        // de guías, que no lleva `@` y por eso un escáner anclado a `@AppStorage` la pierde entera.
        var declarations = 0
        for path in Self.appStorageFiles {
            declarations += code(path).components(separatedBy: "@AppStorage").count - 1
            declarations += code(path).components(separatedBy: "= AppStorage(wrappedValue:").count - 1
        }
        #expect(declarations == 10, """
                hay \(declarations) usos de `@AppStorage`, se esperaban 10. Uno nuevo hereda el store \
                de la raíz automáticamente: comprueba que su key esté clasificada en \
                `SessionPreferenceKeys` y actualiza este conteo.
                """)
    }

    // MARK: 4 · DataWipeService

    @Test("«Vaciar mis datos» barre el dominio de quien lo pulsa, no el del dueño")
    func dataWipeIsWired() {
        // Alcanzable por la invitada sin un solo guard: `ProfileView.swift:961` es un `NavigationLink`
        // incondicional. Con `.standard` clavado, la visita borraba las ~114 preferencias del DUEÑO.
        let src = code("Yala/Utils/DataWipeService.swift")
        #expect(src.contains("removeUserPreferenceKeys(from: SessionDefaults.current)"),
                "el call-site de `resetAllUserPreferences` sigue pasando `.standard`")
        #expect(!src.contains("removeUserPreferenceKeys(from: .standard)"),
                "queda el `.standard` clavado en el call-site del wipe")
    }

    // MARK: 5 · LanguageManager (D2)

    @Test("el idioma de la visita no se queda en el teléfono del dueño")
    func languageManagerIsWired() {
        // D2, decisión del owner: `appLanguageOverride` vive en el App Group (`L10n.swift:38-40`), no
        // en `.standard`, así que ninguno de los otros cuatro consumidores lo alcanza. Sin esto la
        // visita cambia el idioma y el dueño recupera su móvil con la app en otro idioma.
        //
        // Y el motivo de peso no es el bug sino su VERIFICACIÓN: el criterio E2E del ticket exige
        // comprobar el idioma, y ese paso puede salir VERDE sin estar arreglado, porque
        // `applyRemoteValues` se lo restaura al dueño desde su iKV intacto — un test que pasa por la
        // razón equivocada.
        let src = code("Yala/Utils/L10n.swift")
        #expect(src.contains("SessionDefaults"),
                """
                `LanguageManager` no consulta la puerta: el idioma de la visita cae en el App Group \
                compartido y el dueño recupera la app en otro idioma
                """)
    }

    // MARK: Los lectores que NO pueden quedarse atrás

    @Test("los mirrors de `SessionState` leen y escriben el MISMO dominio que su escritor")
    func sessionStateMirrorsAreWired() {
        // El riesgo nº1 del ticket, en su instancia más fácil de olvidar: `SessionState` tiene tres
        // mirrors que escriben `UserDefaults.standard` DIRECTO, y sus keys son de la persona
        // (`financialMindset` y `expensesOnlyMode` por la red; `needsPostOnboardingTrial` por decisión
        // del owner). Un mirror en `.standard` con `AppPreferences` en el cajón es el «lector
        // desalineado»: la visita toca un ajuste y no pasa nada visible.
        let src = code("Yala/App/Models/SessionState.swift")
        let mirrors = ["financialMindset", "expensesOnlyMode", "needsPostOnboardingTrial",
                       "customPeriodStart", "customPeriodEnd"]
        for key in mirrors {
            let lines = src.split(separator: "\n").filter { $0.contains(key) }
            let onStandard = lines.filter { $0.contains("UserDefaults.standard") }
            #expect(onStandard.isEmpty, Comment(rawValue: """
                `\(key)` sigue clavado a `UserDefaults.standard` en `SessionState`:
                \(onStandard.map(\.description).joined(separator: "\n"))
                """))
        }
    }

    @Test("`YalaFormatterStatic` lee el dominio de quien mira la pantalla")
    func formatterStaticIsWired() {
        // Su docblock promete output «byte-identical to `appPreferences.X`». Con `AppPreferences` en el
        // cajón y este leyendo `.standard`, la promesa se rompe: los importes de la visita se
        // formatearían con los decimales y el formato de divisa del DUEÑO.
        let src = code("Yala/App/Views/Shared/YalaFormatterStatic.swift")
        #expect(!src.contains("UserDefaults.standard"),
                "`YalaFormatterStatic` sigue leyendo `.standard` mientras su gemelo lee el cajón")
    }

    // MARK: El lector desalineado — riesgo nº1 del ticket

    /// Ficheros donde una key de PERSONA puede seguir leyéndose de `.standard`, con su porqué.
    /// **Cada entrada es una decisión, no una excepción de conveniencia.**
    static let misalignedReaderExceptions: [String: String] = [
        "Yala/Services/WidgetDataCache.swift":
            "El snapshot que consume el WIDGET, que es un proceso hermano del DUEÑO y no sabe nada de "
            + "sesiones. Servirle el formato de divisa o la semana de la visita sería el mismo daño por "
            + "la puerta de al lado. El caso completo —qué debe ver el widget durante una visita— tiene "
            + "ticket propio (D1, decisión del owner: sello + servir los datos de la invitada) y NO "
            + "entra aquí.",
    ]

    /// **La red que impide que F3 quede a medias.** Un escritor movido al cajón con su lector todavía
    /// en `.standard` produce una app incoherente durante toda la visita —ella toca un ajuste y no
    /// pasa nada, o ve mezcladas las suyas con las del dueño—, que el ticket declara PEOR que el bug
    /// original. Al escribirlo había **40**, así que esto no es teórico ni preventivo.
    @Test("ninguna key de la persona se lee de `.standard` fuera de las excepciones declaradas")
    func noMisalignedReaders() {
        let person = SessionPreferenceKeys.person
        // Símbolos de `AppPreferences.Keys` que resuelven a una key de persona.
        let ap = code("Yala/App/Services/AppPreferences.swift")
        var symbols: [String] = []
        for m in ap.matches(of: /static let ([a-zA-Z]+) = "([^"]+)"/) where person.contains(String(m.2)) {
            symbols.append("Keys.\(m.1)")
        }

        var offenders: [String] = []
        for path in SessionDefaultsScan.allSwiftFiles() {
            if Self.misalignedReaderExceptions.keys.contains(path) { continue }
            for (n, line) in code(path).split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where line.contains("UserDefaults.standard") {
                // Tres formas de nombrar una key de persona, y las tres cuentan: el literal, el
                // símbolo de `AppPreferences.Keys`, y las FAMILIAS dinámicas (`nudge.interacted.<x>`,
                // `guide.<id>.dismissed`), que un `Set` exacto perdería enteras.
                let byLiteral = person.contains { line.contains("\"\($0)\"") }
                let bySymbol = symbols.contains { line.contains($0) }
                let byFamily = SessionPreferenceKeys.personPrefixes.contains { line.contains("\"\($0)") }
                if byLiteral || bySymbol || byFamily {
                    offenders.append("\(path):\(n + 1)  \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        #expect(offenders.isEmpty, """
            \(offenders.count) lector(es) de una key de PERSONA siguen en el dominio del dueño.
            O se mueven a `SessionDefaults.current` en ESTE commit, o se declaran en
            `misalignedReaderExceptions` con su porqué:
            \(offenders.joined(separator: "\n"))
            """)
    }

    @Test("las excepciones de lector desalineado explican su porqué")
    func misalignedExceptionsCarryReasons() {
        for (path, reason) in Self.misalignedReaderExceptions {
            #expect(!code(path).isEmpty, "la excepción apunta a `\(path)`, que no existe")
            #expect(reason.count >= 60, "la excepción de `\(path)` no explica nada")
        }
    }

    // MARK: La prueba que carga el peso

    @Test("con la visita dentro, el dominio del dueño no cambia NI UNA key, y vuelve byte-idéntico")
    func ownerDomainIsUntouchedAndRestored() {
        // Es la aserción central del ticket, y ejercita a propósito los MIRRORS de `SessionState`
        // —`financialMindset`, `expensesOnlyMode`, `needsPostOnboardingTrial`, el rango del período—
        // porque son los que escriben `UserDefaults` directo y los que caían en rojo antes de F3.
        let userID = "guest-\(UUID().uuidString)"
        let owner = makeIsolatedDefaults(prefix: "f3.owner")

        // El dueño, con sus cosas puestas.
        let ownerState: [String: Any] = [
            "userName": "Jür",
            "defaultCurrencyCode": "PEN",
            AppPreferences.Keys.financialMindset: "patrimonial",
            "tabBarConfiguration": "{\"owner\":true}",
            "needsPostOnboardingTrial": true,
            "customPeriodStart": 1.0,
        ]
        for (k, v) in ownerState { owner.set(v, forKey: k) }
        let before = ownerState.keys.reduce(into: [String: String]()) { $0[$1] = "\(owner.object(forKey: $1) ?? "")" }

        // Entra la visita y escribe LO MISMO, con otros valores.
        SecondarySessionStore.activate(userID: userID, owner)
        defer { SessionDefaults.destroySuite(forUserID: userID, isTestEnvironment: false) }
        let guest = try! #require(SessionDefaults.resolve(owner: owner, isTestEnvironment: false) as UserDefaults?)
        #expect(guest !== owner)
        guest.set("Ana", forKey: "userName")
        guest.set("EUR", forKey: "defaultCurrencyCode")
        guest.set("cashFlow", forKey: AppPreferences.Keys.financialMindset)
        guest.set("{\"guest\":true}", forKey: "tabBarConfiguration")
        guest.set(false, forKey: "needsPostOnboardingTrial")
        guest.set(99.0, forKey: "customPeriodStart")

        // Ni una key del dueño se movió.
        for (k, v) in before {
            #expect("\(owner.object(forKey: k) ?? "")" == v,
                    "`\(k)` del dueño cambió durante la sesión de la visita")
        }

        // Y tras el wipe de salida, byte-idéntico — más la aserción gemela: el cajón ya no existe.
        SecondarySessionStore.markEntryPurgeDone(owner)
        SecondarySessionStore.armWipe(owner)
        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: owner, deleteFiles: { _, _ in true }, purge: {},
            destroySessionDomain: { SessionDefaults.destroySuite(forUserID: $0, isTestEnvironment: false) })

        for (k, v) in before {
            #expect("\(owner.object(forKey: k) ?? "")" == v, "`\(k)` del dueño no volvió intacta")
        }
        let name = try! #require(SessionDefaults.suiteName(forUserID: userID))
        let domain = UserDefaults.standard.persistentDomain(forName: name)
        #expect(domain == nil || domain?.isEmpty == true, "el cajón de la visita sobrevivió al wipe")
    }

    @Test("`FullModeActivationView` escribe la barra de pestañas donde la lee su dueño")
    func fullModeActivationIsWired() {
        // Medida como alcanzable en secundaria y SIN guard. Escribe `tabBarConfiguration` junto a
        // `usageFocus`: son el PAR del inventario, y separarlos deja la barra del cajón pintándose
        // mientras `selectMainTab` decide contra la del dueño.
        let src = code("Yala/App/Views/Groups/FullModeActivationView.swift")
        #expect(!src.contains("UserDefaults.standard"),
                "sigue escribiendo la barra de pestañas en el dominio del dueño")
    }
}

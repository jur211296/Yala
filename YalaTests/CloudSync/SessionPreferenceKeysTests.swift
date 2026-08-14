//
//  SessionPreferenceKeysTests.swift
//  YalaTests / CloudSync
//
//  El escáner del inventario de preferencias por sesión (M1, F2).
//
//  **Qué carga el peso aquí y qué no.** El test de COMPLETITUD no comprueba que la lista sea
//  correcta —eso no lo puede comprobar una máquina— sino que **ninguna key de la red se quede sin
//  clasificar en silencio**: si mañana alguien añade un `case` a `PrefSyncKey` o una property
//  `synced: true`, este fichero se pone rojo y obliga a decidir de qué lado va. Es el mismo papel que
//  el conteo esperado de `OwnerKeyValueWiringTests`: sin él, un escáner roto pasa en verde sin
//  comprobar nada (la familia de «Executed 0 tests»).
//
//  El test de GRAFÍAS es el que impide que el inventario envejezca sin avisar: cuenta los sitios que
//  nombran cada key **por todas sus escrituras** y suma. Con el conteo sobre una sola grafía, mover
//  un sitio de literal a símbolo lo dejaría verde sin haber medido nada.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Utilidades de escaneo

private let repoRoot: URL = {
    // El bundle de tests vive dentro de DerivedData; el repo se localiza subiendo desde este fichero.
    URL(fileURLWithPath: #filePath)          // …/YalaTests/CloudSync/SessionPreferenceKeysTests.swift
        .deletingLastPathComponent()          // …/YalaTests/CloudSync
        .deletingLastPathComponent()          // …/YalaTests
        .deletingLastPathComponent()          // …/  (raíz del repo)
}()

private func sourceFiles(in folder: String) -> [URL] {
    let base = repoRoot.appendingPathComponent(folder)
    guard let e = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return [] }
    return e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
}

/// El texto de un fichero SIN sus comentarios de línea: el inventario se explica a sí mismo en prosa
/// y contar la prosa haría que documentar un invariante lo rompiera (ya pasó en este repo).
private func code(_ url: URL) -> String {
    guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return "" }
    return raw.split(separator: "\n", omittingEmptySubsequences: false)
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        .joined(separator: "\n")
}

/// La red de completitud, calculada del árbol y no escrita a mano — una lista copiada envejece.
private func completenessNet() -> Set<String> {
    var net = Set(PrefSyncKey.allCases.map(\.rawValue))

    let ap = code(repoRoot.appendingPathComponent("Yala/App/Services/AppPreferences.swift"))
    // `forKey: Keys.x, synced: true` → el símbolo; se resuelve a su literal por el mapa de abajo.
    for m in ap.matches(of: /forKey: Keys\.([a-zA-Z]+), synced: true/) {
        net.insert(AppPreferencesKeyLiterals.map[String(m.1)] ?? String(m.1))
    }
    return net
}

/// `AppPreferences.Keys.<símbolo>` → literal, leído del propio fichero.
private enum AppPreferencesKeyLiterals {
    static let map: [String: String] = {
        let ap = code(repoRoot.appendingPathComponent("Yala/App/Services/AppPreferences.swift"))
        var out: [String: String] = [:]
        for m in ap.matches(of: /static let ([a-zA-Z]+) = "([^"]+)"/) {
            out[String(m.1)] = String(m.2)
        }
        // Las que no son literal sino referencia a un SSOT de otro tipo.
        for m in ap.matches(of: /static let ([a-zA-Z]+) = ([A-Z][a-zA-Z]+)\.userDefaultsKey/) {
            let owner = String(m.2)
            if owner == "UsageFocus" { out[String(m.1)] = UsageFocus.userDefaultsKey }
            if owner == "OnboardingMode" { out[String(m.1)] = OnboardingMode.userDefaultsKey }
        }
        return out
    }()
}

// MARK: - Completitud

@Suite("SessionPreferenceKeys · completitud de la red")
struct SessionPreferenceKeysNetTests {

    @Test("la red se calcula del árbol y NO está vacía (control del instrumento)")
    func netIsNotEmpty() {
        // Sin este control, un escáner que no encuentra los ficheros declararía completitud sobre el
        // conjunto vacío — verde perfecto y hueco.
        let net = completenessNet()
        #expect(net.count >= 40, "la red salió con \(net.count) keys; el escáner no está leyendo el árbol")
        #expect(net.contains("usageFocus"))
        #expect(net.contains("defaultCurrencyCode"))
        #expect(net.contains("appLanguageOverride"))   // PrefSyncKey que NO es synced: true
        #expect(net.contains("moreSectionOrder"))      // synced: true que NO es PrefSyncKey
    }

    /// **Las dos mitades de la red no valen lo mismo, y conviene saber cuál cubre este test.**
    /// Medido con mutantes: añadir un `case` a `PrefSyncKey` **no llega aquí** — lo para antes el
    /// compilador, porque `PreferenceMergeLogic.swift:130` tiene un `switch` exhaustivo. La vía que
    /// nadie más cubre es la otra: una property `synced: true` nueva en `AppPreferences` compila
    /// perfectamente, no rompe ningún `switch`, y se iría al dominio que le tocara al consumidor sin
    /// que nadie hubiera decidido de quién es. **Ése es exactamente el hueco que este test tapa**, y
    /// su mutante (una property `synced: true` sin clasificar) da exit 65 con cero errores de
    /// compilación.
    @Test("TODA key de la red está clasificada: o es de la persona, o es una excepción declarada")
    func everyNetKeyIsClassified() {
        let net = completenessNet()
        let classified = SessionPreferenceKeys.person.union(SessionPreferenceKeys.deviceExceptions.keys)
        let unclassified = net.subtracting(classified).sorted()
        #expect(unclassified.isEmpty, """
            \(unclassified.count) key(s) de la red sin clasificar. Cada una tiene que ir a
            `SessionPreferenceKeys.person` (viaja con la visita) o a `deviceExceptions` CON SU PORQUÉ
            (se queda en el teléfono del dueño):
            \(unclassified.joined(separator: ", "))
            """)
    }

    @Test("ninguna key está en los dos lados a la vez")
    func classificationIsDisjoint() {
        let both = SessionPreferenceKeys.person.intersection(SessionPreferenceKeys.deviceExceptions.keys)
        #expect(both.isEmpty, "clasificada dos veces: \(both.sorted().joined(separator: ", "))")
    }

    @Test("toda excepción declara su porqué, y no de cualquier manera")
    func everyExceptionCarriesItsReason() {
        for (key, reason) in SessionPreferenceKeys.deviceExceptions {
            #expect(reason.count >= 30, "la excepción de `\(key)` no explica nada: «\(reason)»")
        }
    }

    @Test("los PARES añadidos a mano están dentro, y son los cuatro medidos")
    func manuallyAddedPairsArePresent() {
        // No salen de ninguna red: entran porque ACOMPAÑAN a una que sí. Ver la cabecera del
        // inventario — separarlos es el «lector desalineado» en su forma más barata de producir.
        for key in ["tabBarConfiguration", "customPeriodStart", "customPeriodEnd", "financialMindset"] {
            #expect(SessionPreferenceKeys.person.contains(key), "falta el par `\(key)`")
        }
    }

    @Test("las decisiones D6 del owner están dentro")
    func ownerDecisionsArePresent() {
        for key in ["chatQuestionsToday", "transactionsSavedCount", "needsPostOnboardingTrial"] {
            #expect(SessionPreferenceKeys.person.contains(key), "falta la key de D6 `\(key)`")
        }
        // Las OCHO de ProUpsell (decisión del owner, 2026-08-13): describen la relación de UNA persona
        // con la oferta Pro. Ninguna es del dispositivo.
        let pro = SessionPreferenceKeys.person.filter { $0.hasPrefix("pro.") }
        #expect(pro.count == 8, "se esperaban 8 keys `pro.*`, hay \(pro.count): \(pro.sorted())")
    }
}

// MARK: - Grafías

/// Una key y los sitios que la nombran, POR GRAFÍA. El conteo esperado SUMA las grafías: contar una
/// sola deja que mover un sitio de literal a símbolo pase en verde sin comprobar nada.
private struct KeySpelling {
    let key: String
    /// Cada entrada: el texto exacto a buscar en el código.
    let spellings: [String]
    /// Nº de sitios esperados, sumando todas las grafías, bajo `Yala/`.
    let expectedSites: Int
}

@Suite("SessionPreferenceKeys · las N grafías, con conteo")
struct SessionPreferenceKeysSpellingTests {

    /// Sólo las keys cuya dispersión es el riesgo: las que se nombran de más de una forma o desde
    /// más de un servicio. Las que solo viven en `AppPreferences` las cubre su propio `didSet`.
    ///
    /// **Los conteos están MEDIDOS, no estimados**, y el desglose por fichero va escrito al lado: es
    /// lo que convierte un número opaco en algo auditable, y es la lista exacta de sitios que F3
    /// tendrá que mover junto a su escritor.
    private static let watched: [KeySpelling] = [
        // Literal en TRES servicios. El de `DraftService` no estaba en ninguna lista previa —el plan
        // solo citaba `NewTransactionViewModel`— y es justo lo que este conteo existe para cazar.
        // DraftService×4 · NewTransactionViewModel×3 · DataWipeService×1
        KeySpelling(key: "transactionsSavedCount", spellings: ["\"transactionsSavedCount\""], expectedSites: 8),
        // ChatAssistantService×4 · DataWipeService×1
        KeySpelling(key: "chatQuestionsToday", spellings: ["\"chatQuestionsToday\""], expectedSites: 5),
        // SessionState×2 · DataWipeService×1
        KeySpelling(key: "needsPostOnboardingTrial", spellings: ["\"needsPostOnboardingTrial\""], expectedSites: 3),
        // DOS grafías, y la prueba de por qué hacen falta: `SessionState` y `OnboardingView` usan el
        // SÍMBOLO, `DataWipeService` el literal. Contar una sola dejaría fuera a la mitad.
        // OnboardingView×3 · SessionState×2 · AppPreferences×1 · DataWipeService×1
        KeySpelling(key: "financialMindset",
                    spellings: ["\"financialMindset\"", "Keys.financialMindset"], expectedSites: 7),
        // El síntoma titular: la barra de pestañas, con TRES grafías.
        // AppPreferences×4 · DataWipeService×2 · AppBootstrapper×1 · ContentView×1 ·
        // FullModeActivationView×1 · TabBarConfiguration×1
        KeySpelling(key: "tabBarConfiguration",
                    spellings: ["\"tabBarConfiguration\"", "Keys.tabConfigJSON",
                                "TabBarConfiguration.storageKey"], expectedSites: 10),
        // Su par: literales sueltos en `SessionState` (escritura y lectura) y en el barrido del wipe.
        // SessionState×3 · DataWipeService×1
        KeySpelling(key: "customPeriodStart", spellings: ["\"customPeriodStart\""], expectedSites: 4),
        KeySpelling(key: "customPeriodEnd", spellings: ["\"customPeriodEnd\""], expectedSites: 4),
    ]

    /// Cuenta ocurrencias de una grafía en el CÓDIGO (sin comentarios) de todo `Yala/`, **excluyendo
    /// el propio inventario**: `SessionPreferenceKeys.swift` nombra cada key una vez por declararla,
    /// y contarlo ataría el conteo de escritores a la forma de la lista — añadir una key movería
    /// números que no tienen nada que ver con ella.
    private func sites(of spelling: String) -> Int {
        sourceFiles(in: "Yala")
            .filter { $0.lastPathComponent != "SessionPreferenceKeys.swift" }
            .reduce(0) { acc, url in
                acc + code(url).components(separatedBy: spelling).count - 1
            }
    }

    @Test("cada key vigilada aparece en el nº de sitios medido, sumando TODAS sus grafías")
    func spellingCountsMatch() {
        for w in Self.watched {
            let total = w.spellings.reduce(0) { $0 + sites(of: $1) }
            #expect(total == w.expectedSites, """
                `\(w.key)`: \(total) sitios, se esperaban \(w.expectedSites).
                Si añadiste o quitaste un escritor/lector, actualiza el conteo Y comprueba que el
                sitio nuevo escribe en el dominio que le toca. Grafías vigiladas: \(w.spellings).
                """)
        }
    }

    @Test("toda key vigilada está clasificada como de la persona")
    func watchedKeysAreClassified() {
        for w in Self.watched {
            #expect(SessionPreferenceKeys.person.contains(w.key),
                    "`\(w.key)` se vigila pero no está en el inventario")
        }
    }
}

// MARK: - El caso que el escáner no vería por sí solo

@Suite("SessionPreferenceKeys · DataWipeService, el consumidor invisible")
struct SessionPreferenceKeysWipeScanTests {

    @Test("`removeUserPreferenceKeys` nombra sus keys contra el PARÁMETRO, no contra `.standard`")
    func wipeNamesKeysAgainstItsParameter() {
        // Éste es el motivo de que `DataWipeService` sea invisible para un escáner ingenuo: sus ~114
        // `removeObject` se nombran contra `defaults`, y el `.standard` vive una capa MÁS ARRIBA
        // (`resetAllUserPreferences`, `:438`), en una línea que no nombra ni una sola key. Un escáner
        // que busque «key + .standard» en la misma línea no encuentra nada y declara limpio.
        let src = code(repoRoot.appendingPathComponent("Yala/Utils/DataWipeService.swift"))
        let fn = src.components(separatedBy: "static func removeUserPreferenceKeys(from defaults: UserDefaults) {")
        #expect(fn.count == 2, "no se encontró `removeUserPreferenceKeys` — ¿se renombró?")
        let body = fn[1].components(separatedBy: "\n    }\n")[0]

        let removals = body.components(separatedBy: "defaults.removeObject(forKey:").count - 1
        #expect(removals >= 100, "sólo \(removals) borrados; el escáner no está leyendo la función")
        #expect(!body.contains("UserDefaults.standard"),
                "la función nombra `.standard` directamente: el dominio ya no lo decide su llamador")

        // Y el call-site que sí fija el dominio, en una línea sin ninguna key. Hasta F3 pasaba
        // `.standard` clavado; desde F3 pasa la puerta, y el invariante que importa es el MISMO: el
        // dominio lo decide el llamador, no la función.
        #expect(src.contains("removeUserPreferenceKeys(from: SessionDefaults.current)"),
                "el call-site de `resetAllUserPreferences` ya no fija el dominio por la puerta")
    }

    @Test("las keys del wipe se nombran con las DOS grafías dentro de la misma función")
    func wipeMixesBothSpellings() {
        // Medido: `:494` usa el símbolo y `:507` el literal. Es la razón de que el conteo por una sola
        // grafía sea inútil aquí.
        let src = code(repoRoot.appendingPathComponent("Yala/Utils/DataWipeService.swift"))
        let body = src.components(separatedBy: "static func removeUserPreferenceKeys(from defaults: UserDefaults) {")[1]
            .components(separatedBy: "\n    }\n")[0]
        #expect(body.contains("AppPreferences.Keys."), "ya no usa el símbolo — re-mide el escáner")
        #expect(body.contains("forKey: \""), "ya no usa literales — re-mide el escáner")
    }
}

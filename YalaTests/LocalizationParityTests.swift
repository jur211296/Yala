//
//  LocalizationParityTests.swift
//  YalaTests
//
//  Tests CI que detectan drift entre los .strings de los locales soportados.
//  Falla si una key existe en es pero no en en (o viceversa), si los placeholders
//  no coinciden, o si hay strings vacíos.
//

import Foundation
import Testing

@testable import Yala

struct LocalizationParityTests {

    // Locale de referencia para paridad. Hoy es `es` (será es-419 post-M9).
    private let referenceLocale = "es"

    // MARK: - paridad de keys

    /// Locales BASE (sin parent) deben tener paridad completa con el reference.
    /// Las variantes regionales (parent != nil) son subset por diseño.
    private var baseLocalesExcludingReference: [SupportedLocale] {
        SupportedLocale.allCases.filter { $0.parent == nil && $0.code != referenceLocale }
    }

    @Test func everyBaseLocale_hasAllKeys_fromReference() {
        let reference = StringsFileParser.parseStrings(forLocale: referenceLocale)
        #expect(!reference.isEmpty, "Reference locale '\(referenceLocale)' has zero strings — bundle path issue")

        let referenceKeys = Set(reference.keys)

        for locale in baseLocalesExcludingReference {
            let localeStrings = StringsFileParser.parseStrings(forLocale: locale.code)
            #expect(!localeStrings.isEmpty, "Base locale '\(locale.code)' has zero strings")
            let localeKeys = Set(localeStrings.keys)

            let missing = referenceKeys.subtracting(localeKeys)
            #expect(missing.isEmpty, "Base locale '\(locale.code)' is missing \(missing.count) keys from \(referenceLocale): \(missing.sorted().prefix(5))")
        }
    }

    @Test func noOrphanKeys_inAnyBaseLocale() {
        let reference = StringsFileParser.parseStrings(forLocale: referenceLocale)
        let referenceKeys = Set(reference.keys)

        for locale in baseLocalesExcludingReference {
            let localeStrings = StringsFileParser.parseStrings(forLocale: locale.code)
            let localeKeys = Set(localeStrings.keys)

            let orphans = localeKeys.subtracting(referenceKeys)
            #expect(orphans.isEmpty, "Base locale '\(locale.code)' has \(orphans.count) orphan keys not in \(referenceLocale): \(orphans.sorted().prefix(5))")
        }
    }

    @Test func variants_areSubsetOfParent() {
        // Variantes regionales (parent != nil) no deben tener keys ajenas al padre. Desde el lote 12.4 cada variante
        // tiene su `.stringsdict` (copia adaptada del padre), así que los dos universos son `.strings ∪ .stringsdict`.
        // Antes la variante llevaba el plural como línea plana con la forma `other`, y con la variante como idioma
        // del sistema decía «1 seleccionados».
        for variant in SupportedLocale.allCases where variant.parent != nil {
            guard let parent = variant.parent else { continue }
            let variantKeys = Set(StringsFileParser.parseStrings(forLocale: variant.code).keys)
                .union(StringsFileParser.parseStringsdictKeys(forLocale: variant.code))
            let parentKeys = Set(StringsFileParser.parseStrings(forLocale: parent.code).keys)
                .union(StringsFileParser.parseStringsdictKeys(forLocale: parent.code))

            let orphans = variantKeys.subtracting(parentKeys)
            #expect(orphans.isEmpty, "Variant '\(variant.code)' has \(orphans.count) keys not in parent '\(parent.code)' (.strings ∪ .stringsdict): \(orphans.sorted())")
        }
    }

    /// Las variantes DEBEN materializar todas las keys del padre, no solo los overrides.
    /// iOS NO hace fallback per-key cuando la variante es el idioma de SISTEMA: resuelve
    /// `Bundle.main` contra el `.lproj` de la variante y devuelve la key cruda si falta.
    /// El fallback manual de `ls()` (variante→padre→main) solo aplica con override in-app,
    /// y los ~290 `NSLocalizedString` directos ni siquiera pasan por `ls()`. Combinado con
    /// `variants_areSubsetOfParent`, esto fuerza paridad exacta variante == padre.
    ///
    /// El universo es `.strings ∪ .stringsdict` en los dos lados: los plurales del padre viven en el `.stringsdict`
    /// propio de la variante (lote 12.4). Sin esto, un plural saldría crudo con la variante como idioma de sistema.
    @Test func variants_haveAllKeys_fromParent() {
        for variant in SupportedLocale.allCases where variant.parent != nil {
            guard let parent = variant.parent else { continue }
            let variantKeys = Set(StringsFileParser.parseStrings(forLocale: variant.code).keys)
                .union(StringsFileParser.parseStringsdictKeys(forLocale: variant.code))
            let parentKeys = Set(StringsFileParser.parseStrings(forLocale: parent.code).keys)
                .union(StringsFileParser.parseStringsdictKeys(forLocale: parent.code))

            let missing = parentKeys.subtracting(variantKeys)
            #expect(missing.isEmpty, "Variant '\(variant.code)' is missing \(missing.count) keys from parent '\(parent.code)' (.strings ∪ .stringsdict) — con idioma de sistema se verían CRUDAS. Materializa los valores del padre (los plurales, en su .stringsdict): \(missing.sorted().prefix(5))")
        }
    }

    // MARK: - aliases catch-all

    /// Los aliases catch-all (`es`, `pt`) DEBEN ser copia IDÉNTICA en VALOR de su base
    /// (`es-419`, `pt-BR`) — contrato declarado en `SupportedLocale.swift` ("Alias catch-all —
    /// copia idéntica de …"), en L10N.md y en los commits del split (M7 `d868009d`, M9 `4fe8abcc`).
    ///
    /// Este test existe porque el contrato se rompió en silencio durante ~3 meses: ningún test
    /// comparaba VALORES entre locales (solo presencia de keys, placeholders, vacíos y duplicados),
    /// y `add-l10n-key.sh` daba a `pt` un `[NEEDS_TRANSLATION]` que alguien traducía a mano →
    /// `pt` derivó a portugués EUROPEO en 272 de 3925 keys (2026-04-30 → 2026-07-21).
    ///
    /// Por qué importa: los aliases NO son un caso exótico. iOS entrega el idioma preferido CON
    /// región, y CFBundle solo enruta a `pt-BR`/`pt-PT` cuando la región está en su cadena CLDR.
    /// `pt.lproj` sirve a TODO portugués con región fuera del bloque lusófono — la diáspora
    /// brasileña (US, JP, DE, PE…) —, y `es.lproj` a todo hispanohablante fuera de LatAm.
    ///
    /// Los aliases son ARTEFACTOS GENERADOS: `add-l10n-key.sh` los regenera por copia. Si este
    /// test falla, NO edites el alias a mano — vuelve a correr el script (o copia la base).
    @Test func aliases_haveIdenticalValues_toTheirBase() {
        for (aliasCode, baseCode) in [("es", "es-419"), ("pt", "pt-BR")] {
            let alias = StringsFileParser.parseStrings(forLocale: aliasCode)
            let base = StringsFileParser.parseStrings(forLocale: baseCode)
            #expect(!alias.isEmpty, "Alias '\(aliasCode)' has zero strings — bundle path issue")
            #expect(!base.isEmpty, "Base '\(baseCode)' has zero strings — bundle path issue")

            let divergent = alias.keys
                .filter { base[$0] != nil && base[$0] != alias[$0] }
                .sorted()
            #expect(
                divergent.isEmpty,
                """
                Alias '\(aliasCode)' diverge de su base '\(baseCode)' en \(divergent.count) valores. \
                Los aliases son COPIA IDÉNTICA (contrato de SupportedLocale/L10N.md): no se traducen \
                a mano. Regenera con qa/scripts/add-l10n-key.sh o copia \(baseCode).lproj → \
                \(aliasCode).lproj. Divergentes: \(divergent.prefix(5))
                """
            )
        }
    }

    // MARK: - placeholders

    @Test func placeholders_matchAcrossLocales() {
        let reference = StringsFileParser.parseStrings(forLocale: referenceLocale)

        for locale in SupportedLocale.allCases where locale.code != referenceLocale {
            let localeStrings = StringsFileParser.parseStrings(forLocale: locale.code)
            for (key, refValue) in reference {
                guard let localeValue = localeStrings[key] else { continue }
                let refPlaceholders = StringsFileParser.extractPlaceholders(from: refValue)
                let localePlaceholders = StringsFileParser.extractPlaceholders(from: localeValue)

                if refPlaceholders.count != localePlaceholders.count {
                    Issue.record("Placeholder count mismatch in '\(locale.code)' key '\(key)': ref has \(refPlaceholders) but locale has \(localePlaceholders)")
                }
            }
        }
    }

    /// Los plurales de cada variante (su `.stringsdict` propio desde el lote 12.4) conservan los placeholders del
    /// plural del padre. `placeholders_matchAcrossLocales` NO los cubre: itera el `.strings` del reference.
    @Test func variantPlurals_matchParentPlaceholders() {
        for variant in SupportedLocale.allCases where variant.parent != nil {
            guard let parent = variant.parent else { continue }
            let parentPlurals = StringsFileParser.parseStringsdictOtherPlaceholders(forLocale: parent.code)
            let variantPlurals = StringsFileParser.parseStringsdictOtherPlaceholders(forLocale: variant.code)
            #expect(!variantPlurals.isEmpty, "Variant '\(variant.code)' sin .stringsdict")
            for (key, parentPlaceholders) in parentPlurals {
                guard let mine = variantPlurals[key] else { continue }  // presencia: variants_haveAllKeys_fromParent
                #expect(mine.sorted() == parentPlaceholders.sorted(),
                        "Variant '\(variant.code)' key '\(key)': \(mine.sorted()) ≠ padre \(parentPlaceholders.sorted())")
            }
        }
    }

    /// Card «En es-ES, es-AR, en-GB y pt-PT los recuentos de uno salen en plural» (lote 12.4). Con la variante como
    /// idioma del sistema iOS resuelve SU `.lproj`, y la línea plana con la forma `other` daba «1 seleccionados».
    /// Se mide con el bundle de cada variante, que es lo que lee `Bundle.main` en ese caso.
    @Test(arguments: [("es-ES", "1 seleccionado", "3 seleccionados"), ("es-AR", "1 seleccionado", "3 seleccionados"),
                      ("pt-PT", "1 selecionado", "3 selecionados"), ("en-GB", "1 selected", "3 selected")])
    func variant_countOfOne_isSingular(_ code: String, _ one: String, _ three: String) throws {
        let path = try #require(Bundle.main.path(forResource: code, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let format = NSLocalizedString("records.selectedCount", bundle: bundle, comment: "")
        #expect(String.localizedStringWithFormat(format, 1) == one)
        #expect(String.localizedStringWithFormat(format, 3) == three)
    }

    // MARK: - empty values

    @Test func noEmptyValues_anywhere() {
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            for (key, value) in strings {
                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Issue.record("Empty value in '\(locale.code)' key '\(key)'")
                }
            }
        }
    }

    /// Falla si una key tiene el marcador `[NEEDS_TRANSLATION]` en cualquier locale.
    /// El script `qa/scripts/add-l10n-key.sh` añade ese marcador como placeholder
    /// cuando propaga una key nueva — el dev DEBE traducir cada locale antes de commit.
    @Test func noNeedsTranslationMarker_anywhere() {
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            for (key, value) in strings {
                if value.contains("[NEEDS_TRANSLATION]") {
                    Issue.record("Locale '\(locale.code)' key '\(key)' tiene placeholder [NEEDS_TRANSLATION] — traduce antes de commit")
                }
            }
        }
    }

    // MARK: - duplicate stringsdict / strings keys

    @Test func noKeyDuplicatedBetweenStringsAndStringsdict() {
        for locale in SupportedLocale.allCases {
            let stringsKeys = Set(StringsFileParser.parseStrings(forLocale: locale.code).keys)
            let stringsdictKeys = StringsFileParser.parseStringsdictKeys(forLocale: locale.code)

            let duplicates = stringsKeys.intersection(stringsdictKeys)
            #expect(duplicates.isEmpty, "Locale '\(locale.code)' has \(duplicates.count) keys in both .strings and .stringsdict: \(duplicates.sorted())")
        }
    }

    // MARK: - keys duplicadas dentro de un mismo .strings

    /// Una key declarada dos veces en un .strings es invisible para el resto de
    /// esta suite: el runtime resuelve la ÚLTIMA declaración y `NSDictionary`
    /// colapsa los duplicados al parsear, así que ni la paridad ni los
    /// placeholders la detectan. Este test lee los archivos FUENTE del repo
    /// (vía `#filePath`, como WidgetLocalizationParityTests) y cuenta
    /// ocurrencias por key en ambos targets.
    @Test func noDuplicateKeys_inAnyLocale() {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        let resourceRoots = ["Yala/Resources", "YalaWidgets/Resources"]
        let keyPattern = #/^\s*"((?:[^"\\]|\\.)*)"\s*=/#

        for root in resourceRoots {
            let rootURL = repoRoot.appendingPathComponent(root)
            let lprojs = (try? FileManager.default.contentsOfDirectory(
                at: rootURL, includingPropertiesForKeys: nil
            ))?.filter { $0.pathExtension == "lproj" } ?? []
            #expect(!lprojs.isEmpty, "'\(root)' has zero .lproj directories — path issue")

            for lproj in lprojs.sorted(by: { $0.path < $1.path }) {
                let stringsURL = lproj.appendingPathComponent("Localizable.strings")
                guard let content = try? String(contentsOf: stringsURL, encoding: .utf8) else {
                    continue
                }
                var counts: [String: Int] = [:]
                for line in content.split(separator: "\n") {
                    if let match = line.firstMatch(of: keyPattern) {
                        counts[String(match.1), default: 0] += 1
                    }
                }
                let dups = counts.filter { $0.value > 1 }.keys.sorted()
                #expect(
                    dups.isEmpty,
                    "\(root)/\(lproj.lastPathComponent) has duplicate keys (the LAST one silently wins at runtime): \(dups.prefix(8))"
                )
            }
        }
    }

    // MARK: - Terminología: una sola forma por idioma (decisión de Jürgen, 2026-10-26)

    /// Cómo se llama la pestaña Panel en cada idioma. La decisión fue renombrar la pestaña a «Panel» en todos (antes
    /// «Home», «Accueil», «Übersicht», «Início»…, mientras la prosa ya decía «Panel»), con la palabra que su prosa usaba.
    private static let panelWord: [String: String] = [
        "es": "Panel", "es-419": "Panel", "es-ES": "Panel", "es-AR": "Panel", "en": "Panel", "en-GB": "Panel",
        "de": "Panel", "fr": "Panel", "it": "Panel", "nl": "Panel", "pl": "Panel",
        "pt": "Painel", "pt-BR": "Painel", "pt-PT": "Painel", "ja": "パネル", "zh-Hans": "面板",
    ]

    /// El asistente se llama según el idioma, y cada idioma con un solo nombre.
    private static let assistantName: [String: String] = [
        "es": "Yala IA", "es-419": "Yala IA", "es-ES": "Yala IA", "es-AR": "Yala IA", "fr": "Yala IA", "it": "Yala IA",
        "pt": "Yala IA", "pt-BR": "Yala IA", "pt-PT": "Yala IA", "de": "Yala KI",
        "en": "Yala AI", "en-GB": "Yala AI", "nl": "Yala AI", "pl": "Yala AI", "ja": "Yala AI", "zh-Hans": "Yala AI",
    ]

    /// Nombres de la pantalla de ajustes descartados por idioma: la pantalla tiene uno y los avisos que mandan a ella
    /// (o a la app Ajustes del iPhone, que iOS llama igual en ese idioma) usan ese.
    private static let discardedSettingsNames: [String: [String]] = [
        "pt": ["Configurações"], "pt-BR": ["Configurações"], "pt-PT": ["Ajustes"], "fr": ["Paramètres"],
    ]

    @Test func everyLocale_hasATermEntry() {
        let codes = Set(SupportedLocale.allCases.map(\.code))
        #expect(Set(Self.panelWord.keys) == codes, "panelWord no cubre los idiomas soportados")
        #expect(Set(Self.assistantName.keys) == codes, "assistantName no cubre los idiomas soportados")
    }

    @Test(arguments: SupportedLocale.allCases.map(\.code))
    func tabPanel_isNamedPanel(_ code: String) throws {
        let strings = StringsFileParser.parseStrings(forLocale: code)
        let word = try #require(Self.panelWord[code])
        #expect(strings["tab.panel"] == word, "\(code): la pestaña se llama «\(strings["tab.panel"] ?? "nil")», no «\(word)»")
    }

    /// Todo texto que en es-419 nombra el Panel lo nombra con la palabra de la pestaña en cada idioma (en polaco
    /// declinada: «Panelu» contiene «Panel»).
    @Test(arguments: SupportedLocale.allCases.map(\.code))
    func textsThatNameThePanel_useTheTabWord(_ code: String) throws {
        let reference = StringsFileParser.parseStrings(forLocale: "es-419")
        let strings = StringsFileParser.parseStrings(forLocale: code)
        let word = try #require(Self.panelWord[code])
        let keys = reference.filter { $0.value.range(of: #"\bPanel\b"#, options: .regularExpression) != nil }.keys
        #expect(keys.count > 30, "es-419: se esperaban decenas de textos con «Panel»; ¿bundle?")
        for key in keys.sorted() {
            guard let value = strings[key] else { continue }
            #expect(value.contains(word), "\(code) · \(key): no nombra el Panel como «\(word)»: \(value)")
        }
    }

    @Test(arguments: SupportedLocale.allCases.map(\.code))
    func settingsScreen_hasOneName(_ code: String) {
        let strings = StringsFileParser.parseStrings(forLocale: code)
        #expect(strings["settings.title"] == strings["profile.title"], "\(code): la pantalla de ajustes tiene dos nombres")
        for discarded in Self.discardedSettingsNames[code] ?? [] {
            let offenders = strings.filter { $0.value.contains(discarded) }.keys.sorted()
            #expect(offenders.isEmpty, "\(code): «\(discarded)» en \(offenders)")
        }
    }

    @Test(arguments: SupportedLocale.allCases.map(\.code))
    func assistant_hasOneName(_ code: String) throws {
        let strings = StringsFileParser.parseStrings(forLocale: code)
        let name = try #require(Self.assistantName[code])
        let others = Set(Self.assistantName.values).subtracting([name])
        #expect(strings.values.contains { $0.contains(name) }, "\(code): ningún texto nombra a «\(name)»")
        for other in others.sorted() {
            let offenders = strings.filter { $0.value.contains(other) }.keys.sorted()
            #expect(offenders.isEmpty, "\(code): «\(other)» en \(offenders); el asistente aquí es «\(name)»")
        }
    }

}

struct BundleLocaleDriftTests {

    @Test func bundleLocales_matchSupportedLocaleEnum() {
        let bundleLocales = Set(Bundle.main.localizations).subtracting(["Base"])
        let enumLocales = Set(SupportedLocale.allCases.map { $0.bundleResourceName })

        // Bundle puede tener locales que el enum no expone (e.g. aliases temporales).
        // El test mínimo es que TODAS las del enum estén en el bundle.
        let missingFromBundle = enumLocales.subtracting(bundleLocales)
        #expect(missingFromBundle.isEmpty, "SupportedLocale cases sin .lproj en bundle: \(missingFromBundle.sorted())")
    }
}

struct StringsdictParityTests {

    @Test func variants_haveTheSamePluralKeysAsTheirParent() {
        for variant in SupportedLocale.allCases where variant.parent != nil {
            guard let parent = variant.parent else { continue }
            let mine = StringsFileParser.parseStringsdictKeys(forLocale: variant.code)
            let theirs = StringsFileParser.parseStringsdictKeys(forLocale: parent.code)
            #expect(mine == theirs, "Plurales de '\(variant.code)': faltan \(theirs.subtracting(mine).sorted().prefix(5)), sobran \(mine.subtracting(theirs).sorted().prefix(5))")
        }
    }

    @Test func baseLocalesWithStringsdict_haveSameKeys() {
        // Las variantes regionales tienen su propio stringsdict desde el lote 12.4 y se comparan con su padre
        // (`variants_haveTheSamePluralKeysAsTheirParent`). Aquí, los BASE contra el reference.
        let referenceKeys = StringsFileParser.parseStringsdictKeys(forLocale: "es")
        #expect(referenceKeys.count >= 20, "Expected ~22 plural keys in es.stringsdict, got \(referenceKeys.count)")

        let baseLocalesWithStringsdict = SupportedLocale.allCases.filter { locale in
            locale.parent == nil && locale.code != "es" && !StringsFileParser.parseStringsdictKeys(forLocale: locale.code).isEmpty
        }

        for locale in baseLocalesWithStringsdict {
            let keys = StringsFileParser.parseStringsdictKeys(forLocale: locale.code)
            #expect(keys == referenceKeys, "Stringsdict drift in '\(locale.code)': missing \(referenceKeys.subtracting(keys).count), extra \(keys.subtracting(referenceKeys).count)")
        }
    }

    @Test func pluralRule_pl_hasOneFewManyOther() {
        // Polonia es el único locale con 4 reglas plurales (one/few/many/other).
        // Verifica que el .stringsdict de pl declare las 4 formas en al menos
        // una de las keys plurales (e.g. records.deleteConfirmTitle).
        guard let path = Bundle.main.path(forResource: "pl", ofType: "lproj"),
              let bundle = Bundle(path: path),
              let url = bundle.url(forResource: "Localizable", withExtension: "stringsdict"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else {
            Issue.record("pl.lproj/Localizable.stringsdict not found")
            return
        }

        guard let entry = dict["records.deleteConfirmTitle"] as? [String: Any],
              let countDict = entry["count"] as? [String: Any] else {
            Issue.record("records.deleteConfirmTitle missing in pl stringsdict")
            return
        }

        #expect(countDict["one"] != nil, "pl plural rule 'one' missing")
        #expect(countDict["few"] != nil, "pl plural rule 'few' missing (2-4)")
        #expect(countDict["many"] != nil, "pl plural rule 'many' missing (5+, special endings)")
        #expect(countDict["other"] != nil, "pl plural rule 'other' missing (decimals)")
    }

    /// Sustituye a `variants_doNotCreateOwnStringsdict` (M4), que exigía lo contrario: «stringsdict es all-or-nothing
    /// por archivo, y las variantes heredan del padre». La premisa de la herencia es falsa con la variante como idioma
    /// del SISTEMA (`.claude/rules/l10n.md`: iOS no hace fallback por clave), y la salida que se tomó —la línea plana
    /// con la forma `other`— decía «1 seleccionados». Desde el lote 12.4 la variante lleva el `.stringsdict` ENTERO
    /// (el coste que M4 quería evitar, asumido) y aquí se exige que no le falte ninguna forma del padre.
    @Test func variants_ownStringsdict_hasEveryPluralFormOfTheParent() {
        for variant in SupportedLocale.allCases where variant.parent != nil {
            guard let parent = variant.parent else { continue }
            let mine = StringsFileParser.parseStringsdictOtherPlaceholders(forLocale: variant.code)
            let theirs = StringsFileParser.parseStringsdictOtherPlaceholders(forLocale: parent.code)
            #expect(!mine.isEmpty, "Variant '\(variant.code)' sin .stringsdict: con la variante como idioma del sistema los plurales salen con la forma de muchos")
            #expect(Set(mine.keys) == Set(theirs.keys), "Variant '\(variant.code)': plurales distintos de '\(parent.code)'")
        }
    }
}

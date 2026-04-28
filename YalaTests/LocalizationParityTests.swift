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
        // Variantes regionales (parent != nil) deben ser subset de las keys del padre.
        // Por definición las variantes solo contienen overrides — nada nuevo.
        for variant in SupportedLocale.allCases where variant.parent != nil {
            guard let parent = variant.parent else { continue }
            let variantKeys = Set(StringsFileParser.parseStrings(forLocale: variant.code).keys)
            let parentKeys = Set(StringsFileParser.parseStrings(forLocale: parent.code).keys)

            let orphans = variantKeys.subtracting(parentKeys)
            #expect(orphans.isEmpty, "Variant '\(variant.code)' has \(orphans.count) keys not in parent '\(parent.code)': \(orphans.sorted())")
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

    // MARK: - duplicate stringsdict / strings keys

    @Test func noKeyDuplicatedBetweenStringsAndStringsdict() {
        for locale in SupportedLocale.allCases {
            let stringsKeys = Set(StringsFileParser.parseStrings(forLocale: locale.code).keys)
            let stringsdictKeys = StringsFileParser.parseStringsdictKeys(forLocale: locale.code)

            let duplicates = stringsKeys.intersection(stringsdictKeys)
            #expect(duplicates.isEmpty, "Locale '\(locale.code)' has \(duplicates.count) keys in both .strings and .stringsdict: \(duplicates.sorted())")
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

    @Test func baseLocalesWithStringsdict_haveSameKeys() {
        // Variantes regionales (pt-PT, etc.) NO crean stringsdict propio (heredan
        // del padre). Solo locales BASE deben tener paridad de keys plurales.
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

    @Test func variants_doNotCreateOwnStringsdict() {
        // Trade-off documentado en M4: stringsdict es all-or-nothing por archivo.
        // Variantes regionales NO crean stringsdict propio salvo que las reglas
        // plurales difieran del padre (no es el caso de pt-PT/es-ES/es-AR/en-GB).
        for variant in SupportedLocale.allCases where variant.parent != nil {
            let keys = StringsFileParser.parseStringsdictKeys(forLocale: variant.code)
            #expect(keys.isEmpty, "Variant '\(variant.code)' must NOT have its own stringsdict (would force duplicating ALL plurals from parent)")
        }
    }
}

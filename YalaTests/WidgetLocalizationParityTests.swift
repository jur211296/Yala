//
//  WidgetLocalizationParityTests.swift
//  YalaTests
//
//  Paridad de los .strings del TARGET WIDGETS (YalaWidgets/Resources). Estos
//  recursos no forman parte del bundle de la app, así que quedan fuera de
//  LocalizationParityTests (que parsea Bundle.main): se leen del repo vía
//  #filePath. Sin esta suite, una variante sparse en el widget extension pasa
//  CI y renderiza TODAS sus strings como keys crudas — iOS no hace fallback
//  per-key cuando la variante es el idioma del sistema.
//

import Foundation
import Testing

@testable import Yala

struct WidgetLocalizationParityTests {

    /// Reference locale del proyecto (misma referencia hispana que el app target).
    private let referenceLocale = "es-419"

    private static let widgetResources: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("YalaWidgets/Resources")
    }()

    private func parseStrings(forLocale code: String) -> [String: String] {
        let url = Self.widgetResources
            .appendingPathComponent("\(code).lproj")
            .appendingPathComponent("Localizable.strings")
        guard let dict = NSDictionary(contentsOf: url) as? [String: String] else { return [:] }
        return dict
    }

    @Test func widgetBaseLocales_haveAllKeys_fromReference() {
        let reference = parseStrings(forLocale: referenceLocale)
        #expect(!reference.isEmpty, "Widget reference locale '\(referenceLocale)' has zero strings — path issue")
        let referenceKeys = Set(reference.keys)

        let baseLocales = SupportedLocale.allCases.filter { $0.parent == nil && $0.code != referenceLocale }
        for locale in baseLocales {
            let keys = Set(parseStrings(forLocale: locale.code).keys)
            let missing = referenceKeys.subtracting(keys)
            #expect(missing.isEmpty, "Widget base locale '\(locale.code)' is missing \(missing.count) keys from \(referenceLocale): \(missing.sorted().prefix(5))")
        }
    }

    @Test func widgetVariants_haveAllKeys_fromParent() {
        let variants = SupportedLocale.allCases.filter { $0.parent != nil }
        #expect(!variants.isEmpty)

        for variant in variants {
            guard let parent = variant.parent else { continue }
            let parentKeys = Set(parseStrings(forLocale: parent.code).keys)
            #expect(!parentKeys.isEmpty, "Widget parent locale '\(parent.code)' has zero strings — path issue")

            let variantKeys = Set(parseStrings(forLocale: variant.code).keys)
            let missing = parentKeys.subtracting(variantKeys)
            #expect(missing.isEmpty, "Widget variant '\(variant.code)' is missing \(missing.count) keys from parent '\(parent.code)': \(missing.sorted().prefix(5))")
        }
    }
}

//
//  ComparativaSimpleStringsParityTests.swift
//  YalaTests
//
//  La tabla propia de la Comparativa simple (`ComparativaSimple.strings`, pedido del 17-nov) está completa en los 16
//  idiomas: iOS no hace el respaldo por clave con el idioma del sistema (`.claude/rules/l10n.md`), así que una clave que
//  falte en una variante sale cruda. Lee los ficheros fuente y además el bundle de la app con la cadena de idioma de Yala.
//

import Foundation
import Testing

@testable import Yala

@Suite("Comparativa simple · los textos en los 16 idiomas")
struct ComparativaSimpleStringsParityTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func table(_ locale: String, file: StaticString = #filePath) throws -> [String: String] {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = repoRoot.appending(path: "Yala/Resources/\(locale).lproj/ComparativaSimple.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }

    @Test(arguments: locales)
    func everyLocale_hasEveryKey_withText(_ locale: String) throws {
        let reference = try Self.table("es-419")
        let strings = try Self.table(locale)
        #expect(Set(strings.keys) == Set(reference.keys), "\(locale): claves distintas de es-419.")
        for (key, value) in strings {
            #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "\(locale): \(key) vacía.")
        }
    }

    /// Los huecos de cada texto casan con los de es-419: un `%2$@` de menos dejaría el período fuera.
    @Test(arguments: locales)
    func everyLocale_keepsThePlaceholders(_ locale: String) throws {
        let reference = try Self.table("es-419")
        let strings = try Self.table(locale)
        func holes(_ s: String) -> Int { s.components(separatedBy: "%").count - 1 }
        for (key, value) in reference {
            #expect(holes(strings[key] ?? "") == holes(value), "\(locale): \(key) cambia los huecos.")
        }
    }

    @Test func aliases_copyTheirReference() throws {
        #expect(try Self.table("es") == Self.table("es-419"))
        #expect(try Self.table("pt") == Self.table("pt-BR"))
    }

    /// Lo que pidió Jürgen para VoiceOver: «subió 27 % frente a octubre».
    @Test func referenceSpanish_readsAsAsked() throws {
        let es = try Self.table("es-419")
        let phrase = String(format: es["comparativaSimple.a11y.up"] ?? "", "27 %",
                            String(format: es["comparativaSimple.versus"] ?? "", "octubre"))
        #expect(phrase == "subió 27 % frente a octubre")
        #expect(String(format: es["comparativaSimple.versusRange"] ?? "", "1–17 de octubre") == "frente al 1–17 de octubre")
    }

    @Test(arguments: locales)
    func theAppBundle_resolvesTheTable(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let value = ComparativaSimpleText.string("a11y.up", resolution: resolution)
        #expect(value == (try Self.table(locale)["comparativaSimple.a11y.up"]))
        #expect(!value.hasPrefix("comparativaSimple."))
    }

    @Test func aMissingKey_comesBackRaw() {
        #expect(ComparativaSimpleText.string("no.existe") == "comparativaSimple.no.existe")
    }
}

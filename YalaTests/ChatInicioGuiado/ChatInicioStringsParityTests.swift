//
//  ChatInicioStringsParityTests.swift
//  YalaTests
//
//  La tabla propia del inicio de Yala IA (`YalaIAInicio.strings`, encargo del 17-nov) está completa en los 16 idiomas:
//  iOS no hace el respaldo por clave con el idioma del sistema (`.claude/rules/l10n.md`), así que una clave que falte en
//  una variante sale cruda. Lee los ficheros fuente y además el bundle de la app con la cadena de idioma de Yala.
//

import Foundation
import Testing

@testable import Yala

@Suite("Yala IA · inicio: los textos en los 16 idiomas")
struct ChatInicioStringsParityTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func table(_ locale: String, file: StaticString = #filePath) throws -> [String: String] {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = repoRoot.appending(path: "Yala/Resources/\(locale).lproj/YalaIAInicio.strings")
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

    /// `es` y `pt` sirven a quien habla esos idiomas fuera de sus regiones: copian a `es-419` y `pt-BR`.
    @Test func aliases_copyTheirReference() throws {
        #expect(try Self.table("es") == Self.table("es-419"))
        #expect(try Self.table("pt") == Self.table("pt-BR"))
    }

    /// Las variantes tienen texto propio donde la gramática cambia: voseo en es-AR, «tu» de Portugal en pt-PT.
    @Test func variants_speakTheirOwnWay() throws {
        #expect(try Self.table("es-AR")["yalaIAInicio.log.reply"]?.contains("Podés") == true)
        #expect(try Self.table("es-AR")["yalaIAInicio.create.reply"]?.contains("querés") == true)
        #expect(try Self.table("pt-PT")["yalaIAInicio.log.reply"]?.contains("Podes") == true)
        #expect(try Self.table("es-ES")["yalaIAInicio.log.userMessage"] == "Apuntaré un gasto")
    }

    /// Lo que pidió Jürgen, palabra por palabra, en es-419.
    @Test func referenceSpanish_saysWhatWasAsked() throws {
        let es = try Self.table("es-419")
        #expect(es["yalaIAInicio.log.userMessage"] == "Anotaré un gasto")
        #expect(es["yalaIAInicio.ask.userMessage"] == "Preguntaré por mis finanzas")
        #expect(es["yalaIAInicio.create.userMessage"] == "Quiero crear algo")
        #expect(es["yalaIAInicio.log.reply"]?.hasPrefix("¡Perfecto! Puedes hacerlo de estas maneras.") == true)
    }

    /// La app empaqueta la tabla y la lee con la cadena de idioma de Yala (variante → padre), no con la del sistema.
    @Test(arguments: locales)
    func theAppBundle_resolvesTheTable(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let reply = YalaIAInicioText.string("log.reply", resolution: resolution)
        #expect(reply == (try Self.table(locale)["yalaIAInicio.log.reply"]))
        #expect(!reply.hasPrefix("yalaIAInicio."))
    }

    /// Una clave que no existe vuelve cruda, no vacía: así se nota.
    @Test func aMissingKey_comesBackRaw() {
        #expect(YalaIAInicioText.string("no.existe") == "yalaIAInicio.no.existe")
    }
}

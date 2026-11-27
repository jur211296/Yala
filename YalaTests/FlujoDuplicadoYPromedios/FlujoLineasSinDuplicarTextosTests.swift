//
//  FlujoLineasSinDuplicarTextosTests.swift
//  YalaTests
//
//  «En tu plan» (encargo del 27-nov-2026, flujo de caja duplicado y promedios) en los 16 idiomas, y que el código lee
//  las claves de la tabla.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · una línea por cosa · textos en los 16 idiomas")
struct FlujoLineasSinDuplicarTextosTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    nonisolated static func repoRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func table(_ locale: String) throws -> [String: String] {
        let url = repoRoot().appending(path: "Yala/Resources/\(locale).lproj/FlujoLineasSinDuplicar.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }

    @Test(arguments: locales)
    func cadaIdioma_tieneCadaClave_conTexto(_ locale: String) throws {
        let referencia = try Self.table("es")
        let textos = try Self.table(locale)
        #expect(Set(textos.keys) == Set(referencia.keys), "\(locale): claves distintas de es.")
        for (clave, valor) in textos {
            #expect(!valor.trimmingCharacters(in: .whitespaces).isEmpty, "\(locale): \(clave) vacía.")
        }
    }

    @Test func alias_copianSuReferencia() throws {
        #expect(try Self.table("es-419") == Self.table("es"))
        #expect(try Self.table("pt") == Self.table("pt-BR"))
    }

    @Test func lasClavesDelCodigo_sonLasDeLaTabla() throws {
        #expect(Set(L10n.FlujoLineasSinDuplicar.claves) == Set(try Self.table("es").keys))
        for clave in L10n.FlujoLineasSinDuplicar.claves {
            #expect(L10n.FlujoLineasSinDuplicar.string(clave) != clave, "Clave sin texto: \(clave)")
        }
    }
}

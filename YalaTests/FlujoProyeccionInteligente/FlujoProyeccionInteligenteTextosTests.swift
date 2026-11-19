//
//  FlujoProyeccionInteligenteTextosTests.swift
//  YalaTests
//
//  Proyección inteligente (19-nov-2026): los textos de la hoja «Otros» que dicen qué se proyectó como fijo y qué se dejó
//  fuera por aislado, en su propia tabla y en los 16 idiomas, y el cableado de la hoja.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · proyección inteligente · textos y cableado")
struct FlujoProyeccionInteligenteTextosTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    nonisolated static func repoRoot(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func table(_ locale: String) throws -> [String: String] {
        let url = repoRoot().appending(path: "Yala/Resources/\(locale).lproj/FlujoProyeccionInteligente.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot().appending(path: path), encoding: .utf8)
    }

    private static func placeholders(_ text: String) -> [String] {
        text.matches(of: /%(\d+\$)?[@d]/).map { String($0.output.0) }.sorted()
    }

    @Test(arguments: locales)
    func cadaIdioma_tieneCadaClave_conTexto_yLosMismosHuecos(_ locale: String) throws {
        let referencia = try Self.table("es")
        let textos = try Self.table(locale)
        #expect(Set(textos.keys) == Set(referencia.keys), "\(locale): claves distintas de es.")
        for (clave, valor) in textos {
            #expect(!valor.trimmingCharacters(in: .whitespaces).isEmpty, "\(locale): \(clave) vacía.")
            #expect(Self.placeholders(valor) == Self.placeholders(referencia[clave] ?? ""),
                    "\(locale): \(clave) no tiene los mismos huecos que en español.")
        }
    }

    @Test func alias_copianSuReferencia() throws {
        #expect(try Self.table("es-419") == Self.table("es"))
        #expect(try Self.table("pt") == Self.table("pt-BR"))
        #expect(try Self.table("en-GB") == Self.table("en"))
    }

    @Test func lasClavesDelCodigo_sonLasDeLaTabla() throws {
        #expect(Set(L10n.FlujoProyeccion.claves) == Set(try Self.table("es").keys))
        for clave in L10n.FlujoProyeccion.claves {
            #expect(L10n.FlujoProyeccion.string(clave) != clave, "Clave sin texto: \(clave)")
        }
    }

    /// Los textos nuevos viven en su tabla, nunca en `Localizable.strings`.
    @Test func ningunaClaveEnLocalizable() throws {
        for locale in Self.locales {
            let localizable = try Self.source("Yala/Resources/\(locale).lproj/Localizable.strings")
            #expect(!localizable.contains("flujoProyeccion."), "\(locale)")
        }
    }

    /// La historia corta dice el mínimo que usa el código, no otro.
    @Test func laHistoriaCorta_nombraElMinimoDelCodigo() {
        #expect(L10n.FlujoProyeccion.historiaCorta(meses: FlujoProyeccionInteligente.Umbrales.mesesMinimos)
            .contains("\(FlujoProyeccionInteligente.Umbrales.mesesMinimos)"))
    }

    // MARK: - Cableado de la hoja

    @Test func laHojaOtros_explicaFijosYAislados_sinBotonesNuevos() throws {
        let hoja = try Self.source("Yala/App/Views/Reports/CashFlow/CashFlowOthersSheet.swift")
        #expect(hoja.contains("projectionSections(other)"))
        #expect(hoja.contains("L10n.FlujoProyeccion.fijosTitulo"))
        #expect(hoja.contains("L10n.FlujoProyeccion.aisladosTitulo"))
        #expect(hoja.contains("\"cashflow_others_fixed_section\""))
        #expect(hoja.contains("\"cashflow_others_isolated_section\""))
        // Un solo botón por fila de categoría, como antes: las secciones nuevas solo explican.
        #expect(hoja.components(separatedBy: "Button {").count - 1 == 1)
    }
}

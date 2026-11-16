//
//  PresupuestoPasadoTextoTests.swift
//  YalaTests
//
//  Jürgen, 14-nov: el presupuesto pasado dice cuánto se pasó y ofrece ajustar el límite, en vez de
//  «¡el próximo período será mejor!». La clave nueva existe en los 16 idiomas con su marcador de monto,
//  y la vieja ya no está.
//

import Foundation
import Testing

@Suite("Texto de presupuesto pasado en los 16 idiomas")
struct PresupuestoPasadoTextoTests {

    private static var resources: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/Resources")
    }

    private static func tables() throws -> [(String, [String: String])] {
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path)
            .filter { $0.hasSuffix(".lproj") }.sorted()
        return try locales.map { locale in
            let url = resources.appendingPathComponent("\(locale)/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            return (locale, table)
        }
    }

    @Test("Son 16 idiomas")
    func dieciseisIdiomas() throws {
        #expect(try Self.tables().count == 16)
    }

    @Test("La clave con monto lleva exactamente un %@", arguments: ["budgets.exceeded.overByAdjust %@"])
    func claveConMonto(_ key: String) throws {
        for (locale, table) in try Self.tables() {
            let value = try #require(table[key], "\(locale) sin \(key)")
            #expect(value.components(separatedBy: "%@").count == 2, "\(locale): \(value)")
        }
    }

    @Test("La acción existe y la clave vieja se retiró")
    func accionYClaveVieja() throws {
        for (locale, table) in try Self.tables() {
            #expect(!(table["budgets.exceeded.adjustLimit"] ?? "").isEmpty, "\(locale)")
            #expect(table["budgets.exceeded.encouragement"] == nil, "\(locale)")
        }
    }
}

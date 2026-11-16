//
//  ProfileSettingsTypeBarrierWiringTests.swift
//  YalaTests
//
//  La primera apertura de Ajustes no se traba descifrando el tipo de la lista (card YALA-IOS-G).
//
//  Sentry, producción 2.2 (7), iPhone en iOS 27.3: «App Hang» con el hilo principal entero en
//  `swift_getTypeByMangledName` → `TypeDecoder::decodeMangledType/decodeGenericArgs`, colgando de
//  `ProfileView.listColumn`. Cada fila de Ajustes pasa por `settingsLink` y `settingsRowContent`; con `some View`, el
//  tipo de la lista nombraba los suyos una vez por fila y el runtime los descifraba todos la primera vez que se abría
//  Ajustes en cada arranque. Medido en el simulador (iPhone 17e, Debug, muestreo del hilo principal a 1 ms, 3 corridas):
//  ~92 ms de ~97 de Ajustes se iban ahí; con las dos funciones devolviendo `AnyView`, ~40 ms.
//
//  El coste solo se ve con un muestreador, así que lo fija leer el fuente: si alguien devuelve estas funciones a
//  `some View`, el tipo vuelve a anidarse y este test cae.
//

import Foundation
import Testing

@testable import Yala

@Suite("Ajustes: barrera de tipo en las filas (source-scan)")
struct ProfileSettingsTypeBarrierWiringTests {

    private static let profileSource = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Yala/App/Views/Profile/ProfileView.swift")

    /// La firma de una función (de su nombre a la llave que abre el cuerpo), en una línea y sin comentarios.
    private static func signature(of function: String) throws -> String {
        let code = try String(contentsOf: profileSource, encoding: .utf8)
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: " ")
        let start = try #require(code.range(of: "private func \(function)"), "No está `\(function)` en ProfileView.")
        let rest = code[start.lowerBound...]
        let end = try #require(rest.firstIndex(of: "{"), "`\(function)` no tiene cuerpo.")
        return rest[..<end].split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    @Test("settingsLink devuelve AnyView")
    func settingsLinkReturnsAnyView() throws {
        let sig = try Self.signature(of: "settingsLink<")
        #expect(sig.hasSuffix("-> AnyView"), "settingsLink volvió a devolver un tipo opaco: \(sig)")
    }

    @Test("settingsRowContent devuelve AnyView")
    func settingsRowContentReturnsAnyView() throws {
        let sig = try Self.signature(of: "settingsRowContent(")
        #expect(sig.hasSuffix("-> AnyView"), "settingsRowContent volvió a devolver un tipo opaco: \(sig)")
    }
}

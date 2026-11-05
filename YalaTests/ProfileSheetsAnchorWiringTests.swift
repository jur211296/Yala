//
//  ProfileSheetsAnchorWiringTests.swift
//  YalaTests
//
//  Ticket `export-filters-reset-when-the-text-size-changes`: con Exportar abierto, cambiar el tamaño del texto devolvía las
//  cuentas a «todas» y plegaba «Más opciones». La hoja colgaba de la lista RAÍZ de la pila de Ajustes (`listColumn`), y el
//  cambio de rasgos reconstruía su contenido desde cero sin cerrarla. Colgada del contenedor (`body`, fuera de la pila),
//  sobrevive. Medido el 2026-11-05 en el simulador con un conductor XCUITest y `simctl ui content_size`: con la hoja en la
//  lista, «Exportar 2 registros» pasaba a «Exportar 5 registros»; en el contenedor, se queda.
//
//  El XCUITest no puede cambiar el tamaño del texto con la app abierta (solo al lanzarla), así que la red es el cableado.
//

import Foundation
import Testing

@Suite("Las hojas de Ajustes cuelgan del contenedor de la pila")
struct ProfileSheetsAnchorWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo de la declaración que empieza por `header`, hasta la siguiente declaración del tipo.
    private static func body(after header: String, in source: String) throws -> Substring {
        let start = try #require(source.range(of: header))
        let rest = source[start.upperBound...]
        let next = rest.range(of: "\n    private ") ?? rest.range(of: "\n    var ") ?? rest.endIndex..<rest.endIndex
        return rest[..<next.lowerBound]
    }

    @Test func theActiveSheet_hangsFromTheContainer_notFromTheRootList() throws {
        let profile = try Self.source("Yala/App/Views/Profile/ProfileView.swift")
        let listColumn = try Self.body(after: "private var listColumn: some View {", in: profile)
        #expect(!listColumn.contains(".sheet(item: $activeSheet"),
                "La hoja de Ajustes volvió a la lista raíz de la pila: un cambio del tamaño del texto la reconstruye.")

        let sheets = try Self.body(after: "private func settingsSheets<Content: View>(_ content: Content) -> some View {",
                                   in: profile)
        #expect(sheets.contains(".sheet(item: $activeSheet"))
        #expect(sheets.contains("ExportRecordsView()"))

        // Y `settingsSheets` envuelve al contenedor en el `body`, fuera de la pila.
        let body = try Self.body(after: "    var body: some View {", in: profile)
        #expect(body.contains("settingsSheets(\n            settingsContainer"))
        #expect(profile.components(separatedBy: ".sheet(item: $activeSheet").count == 2,
                "Un solo anchor para `activeSheet`.")
    }
}

//
//  BuscarSinBarraEnRegistrosTests.swift
//  YalaTests / RegistrosFluidez
//
//  Jürgen, 20-nov-2026: en Registros y en Estadísticas › Registros se quita «Buscar en Registros» (la barra que asomaba al
//  tirar de la lista), porque la pestaña Buscar cumple esa función. Lo que la barra hacía y Buscar no —encontrar por
//  importe y sin tildes— se llevó a Buscar, con la misma regla (`RecordsListSearchLogic`). Lo que no se llevó (buscar solo
//  dentro del período y los filtros a la vista) quedó en una card.
//
//  Source-scan del cableado: la lista no vuelve a montar un campo, y «Todo» de Buscar pasa por la regla de la barra. La
//  regla en sí la fija `RecordsListSearchLogicTests`.
//

import Foundation
import Testing

@Suite("Registros sin barra de búsqueda; Buscar busca como ella (cableado)")
struct BuscarSinBarraEnRegistrosTests {

    private static func code(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
        // Sin comentarios: el que explica por qué se quitó nombra lo que ya no está.
        return source.split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("La lista compartida de Registros no monta ningún campo de búsqueda")
    func laListaNoLlevaCampo() throws {
        for file in [
            "Yala/App/Views/Statistics/RecordsTabView.swift",
            "Yala/App/Views/Records/Compartida/RecordsSharedList.swift",
        ] {
            let text = try Self.code(file)
            for piece in ["RecordsListSearchField(", "TextField(", ".searchable(", "onScrollGeometryChange"] {
                #expect(!text.contains(piece), "\(file) vuelve a montar un buscador (\(piece)).")
            }
        }
    }

    @Test("«Todo» de Buscar usa la regla de la barra: importe y sin tildes")
    func buscarUsaLaReglaDeLaBarra() throws {
        let text = try Self.code("Yala/App/Views/Search/GlobalSearchView.swift")
        #expect(text.contains("RecordsListSearchLogic.query(searchText)"))
        #expect(text.contains("return RecordsListSearchLogic.matches(fields, query: query)"))
        #expect(text.contains("signedAmount: transaction.amount"))
        #expect(!text.contains(".lowercased().contains("), "Un chip volvió a comparar con tildes.")
    }
}

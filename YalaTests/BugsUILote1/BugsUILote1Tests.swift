//
//  BugsUILote1Tests.swift
//  YalaTests
//
//  Bugs de interfaz de 2.3, lote 1 (14-nov):
//  · Flujo de caja: un gasto por debajo de lo planeado en un mes que ya cerró decía «Te quedan». Ahora dice «Te sobró»,
//    como el período cerrado de Presupuestos (card eqw2).
//  · Estadísticas › Registros: el hueco del buscador oculto pintaba un `VStack` vacío y la pila le sumaba su espaciado
//    (card 4wqy). Lo fija un scan del cableado: el XCUITest que mide el aire (`StatisticsHeroLikePanelUITests`) es la red
//    visual.
//

import Foundation
import Testing
@testable import Yala

@Suite("Lote 1 de bugs de interfaz 2.3 · Flujo de caja en un mes pasado")
struct BugsUILote1CashFlowLabelTests {

    @Test("Mes pasado y por debajo de lo planeado: «Te sobró», no «Te quedan»")
    func mesPasadoDiceTeSobro() {
        let label = CashFlowDetailLineRow.expenseLabel(isOver: false, monthIsPast: true)
        #expect(label == L10n.UXL9.leftoverLabel)
        #expect(label != L10n.UXL9.remainingLabel)
    }

    @Test("Mes por venir y por debajo de lo planeado: sigue diciendo «Te quedan»")
    func mesFuturoDiceTeQuedan() {
        #expect(CashFlowDetailLineRow.expenseLabel(isOver: false, monthIsPast: false) == L10n.UXL9.remainingLabel)
    }

    @Test("Pasarse dice «Te pasaste por» en cualquier mes", arguments: [true, false])
    func pasarseEsIgualEnCualquierMes(_ monthIsPast: Bool) {
        #expect(CashFlowDetailLineRow.expenseLabel(isOver: true, monthIsPast: monthIsPast) == L10n.UXL9.overLabel)
    }

    @Test("«Te sobró» existe en los 16 idiomas y no repite «Te quedan»")
    func teSobroEnLosDieciseisIdiomas() throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path)
            .filter { $0.hasSuffix(".lproj") }.sorted()
        #expect(locales.count == 16)
        for locale in locales {
            let url = resources.appendingPathComponent("\(locale)/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            let leftover = try #require(table["budgets.l9.leftoverLabel"], "\(locale) sin «Te sobró»")
            let remaining = try #require(table["budgets.l9.remainingLabel"], "\(locale) sin «Te quedan»")
            #expect(!leftover.isEmpty)
            #expect(leftover != remaining, "\(locale): «Te sobró» y «Te quedan» dicen lo mismo")
        }
    }
}

@Suite("Lote 1 de bugs de interfaz 2.3 · hueco del buscador de Registros (cableado)")
struct BugsUILote1RecordsSearchSlotWiringTests {

    private static func readSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// El cuerpo de `RecordsListSearchSlot`, desde su `var body` hasta el cierre del struct.
    private static func slotBody() throws -> String {
        let source = try readSource("Yala/App/Views/Records/Components/RecordsListSearchField.swift")
        let start = try #require(source.range(of: "struct RecordsListSearchSlot: View {"))
        let rest = source[start.upperBound...]
        let end = try #require(rest.range(of: "\n}\n"))
        // Sin comentarios: el que explica el arreglo nombra el `VStack` que ya no está.
        return rest[..<end.lowerBound]
            .split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("Sin campo, el hueco no pinta ningún contenedor (ni VStack ni HStack ni Group)")
    func elHuecoNoPintaUnContenedorVacio() throws {
        let body = try Self.slotBody()
        for container in ["VStack", "HStack", "ZStack", "Group {"] {
            #expect(!body.contains(container), "El hueco del buscador vuelve a envolver el campo en \(container)")
        }
        #expect(body.contains("if offersSearch"))
    }

    @Test("La animación y la escucha del texto cuelgan de la pila de RecordsTabView")
    func laPilaLlevaElContenedorDelBuscador() throws {
        let tab = try Self.readSource("Yala/App/Views/Statistics/RecordsTabView.swift")
        #expect(tab.contains(".recordsListSearchContainer(viewModel, onQueryChange: onListSearchChange)"))
        let field = try Self.readSource("Yala/App/Views/Records/Components/RecordsListSearchField.swift")
        #expect(field.contains(".onChange(of: viewModel.listSearchText) { _, _ in onQueryChange() }"))
        #expect(field.contains("value: viewModel.isListSearchRevealed"))
    }
}

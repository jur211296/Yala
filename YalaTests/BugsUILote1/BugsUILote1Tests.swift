//
//  BugsUILote1Tests.swift
//  YalaTests
//
//  Bugs de interfaz de 2.3, lote 1 (14-nov):
//  · Flujo de caja: un gasto por debajo de lo planeado en un mes que ya cerró decía «Te quedan». Ahora dice «Te sobró»,
//    como el período cerrado de Presupuestos (card eqw2).
//  · (Retirado el 20-nov-2026 con la barra de búsqueda de Registros.) Estadísticas › Registros: el hueco del buscador oculto pintaba un `VStack` vacío y la pila le sumaba su espaciado
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

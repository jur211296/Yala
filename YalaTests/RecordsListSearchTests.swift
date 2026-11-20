//
//  RecordsListSearchTests.swift
//  YalaTests
//
//  La regla de búsqueda que nació con «Buscar en Registros» (decisión 14 de la revisión 2.3, opción B1): texto sin
//  mayúsculas ni tildes e importe. Desde el 20-nov-2026 la barra de la lista ya no existe (la pestaña Buscar cumple esa
//  función) y la regla la usan la pestaña Buscar, con «Todo», y la hoja «Reusar» de Pagos planificados.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Buscar en Registros · la regla")
struct RecordsListSearchLogicTests {

    private func amount(_ text: String) -> RecordsListSearchLogic.AmountQuery? {
        RecordsListSearchLogic.amount(from: text)
    }

    @Test("Un importe se lee con punto o coma, con moneda y con miles")
    func readsAmountsAsTheyAreWritten() {
        #expect(amount("45.90") == .init(cents: 4590, hasDecimals: true))
        #expect(amount("45,90") == .init(cents: 4590, hasDecimals: true))
        #expect(amount("45,9") == .init(cents: 4590, hasDecimals: true))
        #expect(amount("S/ 45.90") == .init(cents: 4590, hasDecimals: true))
        #expect(amount("US$45.90") == .init(cents: 4590, hasDecimals: true))
        #expect(amount("-45.90") == .init(cents: 4590, hasDecimals: true))
        #expect(amount("1.234,50") == .init(cents: 123_450, hasDecimals: true))
        #expect(amount("1,234.50") == .init(cents: 123_450, hasDecimals: true))
        #expect(amount("1.234") == .init(cents: 123_400, hasDecimals: false))
        #expect(amount("45") == .init(cents: 4500, hasDecimals: false))
    }

    @Test("Una palabra no es un importe, aunque lleve una cifra")
    func wordsAreNotAmounts() {
        #expect(amount("almuerzo") == nil)
        #expect(amount("Bus 12") == nil)
        #expect(amount("") == nil)
        #expect(amount("S/") == nil)
    }

    @Test("Con decimales casa al céntimo, sin signo; sin decimales, toda la parte entera")
    func amountMatchingRule() throws {
        let exact = try #require(amount("45.90"))
        #expect(exact.matches(-45.90))
        #expect(exact.matches(45.9))
        #expect(!exact.matches(-45.00))
        #expect(!exact.matches(-145.90))

        let whole = try #require(amount("45"))
        #expect(whole.matches(-45.00))
        #expect(whole.matches(-45.90))
        #expect(!whole.matches(-46.00))
        #expect(!whole.matches(-4.50))
    }

    @Test("El texto busca en nota, categoría, subcategoría, cuenta y etiquetas, sin mayúsculas ni tildes")
    func textMatchesEveryField() {
        let fields = RecordsListSearchLogic.Fields(
            note: "Almuerzo de trabajo", category: "Alimentación", subcategory: "Restaurantes",
            account: "Cuenta Principal", tags: ["Viaje a Cusco"], signedAmount: -45.90
        )
        func finds(_ text: String) -> Bool {
            RecordsListSearchLogic.matches(fields, query: RecordsListSearchLogic.query(text))
        }
        #expect(finds("almuerzo"))
        #expect(finds("ALIMENTACION"))
        #expect(finds("restaurantes"))
        #expect(finds("principal"))
        #expect(finds("cusco"))
        #expect(finds("45,90"))
        #expect(finds("  almuerzo  "), "Los espacios a los lados no cuentan.")
        #expect(finds(""), "Sin nada escrito, todo casa.")
        #expect(!finds("taxi"))
        #expect(!finds("12.00"))
    }
}

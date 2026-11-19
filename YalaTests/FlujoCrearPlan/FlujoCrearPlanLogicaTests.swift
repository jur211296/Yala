//
//  FlujoCrearPlanLogicaTests.swift
//  YalaTests
//
//  S5 del replanteo: las sugerencias llegan a la subcategoría, se agrupan bajo su categoría, y al crear el límite queda
//  fijo con la cifra calculada. Lógica pura con `@Model` sin contexto.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · crear plan · lógica")
struct FlujoCrearPlanLogicaTests {

    private func linea(
        _ name: String, category: YalaCategory?, sub: Subcategory? = nil, amount: Double = 100,
        method: EstimationMethod = .average6m, selected: Bool = true, recurring: Bool = false,
        payment: ScheduledPayment? = nil
    ) -> SuggestedLine {
        SuggestedLine(
            category: category, subcategory: sub, scheduledPayment: payment, name: name, isIncome: false,
            suggestedAmount: amount, estimationMethod: method, monthsWithActivity: 6, isSelected: selected,
            isRecurring: recurring
        )
    }

    // MARK: - Solo subcategorías

    @Test func unaLineaDeCategoriaConSubcategorias_seRetira() {
        let comida = YalaCategory(name: "Comida", colorHex: "#000000", isIncome: false)
        let super_ = Subcategory(name: "Supermercado", category: comida)
        comida.subcategories = [super_]
        let lineas = [linea("Comida", category: comida), linea("Supermercado", category: comida, sub: super_)]

        let quedan = FlujoCrearPlanLogica.porSubcategoria(lineas).map(\.name)

        #expect(quedan == ["Supermercado"])
    }

    @Test func unaCategoriaSinSubcategoriasVisibles_conservaSuLinea() {
        let mascotas = YalaCategory(name: "Mascotas", colorHex: "#000000", isIncome: false)
        let oculta = Subcategory(name: "Oculta", isVisible: false, category: mascotas)
        mascotas.subcategories = [oculta]
        let gym = YalaCategory(name: "Gym", colorHex: "#000000", isIncome: false)

        let quedan = FlujoCrearPlanLogica.porSubcategoria([
            linea("Mascotas", category: mascotas), linea("Gym", category: gym),
        ]).map(\.name)

        #expect(quedan == ["Mascotas", "Gym"], "no hay detalle de subcategoría que perder")
    }

    @Test func unPagoPlanificado_conservaSuLinea() {
        let hogar = YalaCategory(name: "Hogar", colorHex: "#000000", isIncome: false)
        hogar.subcategories = [Subcategory(name: "Luz", category: hogar)]
        let pago = ScheduledPayment(name: "Alquiler", amount: 1500, currencyCode: "PEN", nextDueDate: .now)

        let quedan = FlujoCrearPlanLogica.porSubcategoria([
            linea("Alquiler", category: hogar, method: .scheduled, payment: pago),
        ])

        #expect(quedan.count == 1)
    }

    // MARK: - Agrupado

    @Test func agrupa_porCategoria_enElOrdenDeSuPrimeraLinea_ySumaLoElegido() {
        let comida = YalaCategory(name: "Comida", colorHex: "#000000", isIncome: false)
        let transporte = YalaCategory(name: "Transporte", colorHex: "#000000", isIncome: false)
        let super_ = Subcategory(name: "Supermercado", category: comida)
        let resto = Subcategory(name: "Restaurantes", category: comida)
        let taxi = Subcategory(name: "Taxi", category: transporte)

        let grupos = FlujoCrearPlanLogica.agrupar([
            linea("Supermercado", category: comida, sub: super_, amount: 600, recurring: true),
            linea("Taxi", category: transporte, sub: taxi, amount: 150),
            linea("Restaurantes", category: comida, sub: resto, amount: 250, selected: false),
        ])

        #expect(grupos.map { $0.categoria?.name } == ["Comida", "Transporte"])
        #expect(grupos[0].lineas.map(\.name) == ["Supermercado", "Restaurantes"])
        #expect(grupos[0].totalElegido == 600, "lo no elegido no suma")
        #expect(grupos[0].elegidas == 1)
        #expect(grupos[0].seRepite, "una línea que se repite basta")
        #expect(!grupos[1].seRepite)
        #expect(grupos[0].id != grupos[1].id)
    }

    @Test func unaLineaSinCategoria_vaAlGrupoSinCategoria() {
        let grupos = FlujoCrearPlanLogica.agrupar([linea("Suelto", category: nil)])
        #expect(grupos.count == 1)
        #expect(grupos[0].categoria == nil)
        #expect(grupos[0].id == "sin-categoria")
    }

    @Test func unaSubcategoriaSinCategoriaEnLaLinea_seAgrupaPorLaDeLaSubcategoria() {
        let hogar = YalaCategory(name: "Hogar", colorHex: "#000000", isIncome: false)
        let luz = Subcategory(name: "Luz", category: hogar)
        let grupos = FlujoCrearPlanLogica.agrupar([linea("Luz", category: nil, sub: luz)])
        #expect(grupos.first?.categoria?.name == "Hogar")
    }

    // MARK: - Límite fijo (P4)

    @Test func alCrear_loCalculadoPorPromedio_pasaAMontoFijo_conSuCifra() {
        let lineas = [
            linea("Seis meses", category: nil, amount: 420, method: .average6m),
            linea("Tres meses", category: nil, amount: 300, method: .average3m),
            linea("Mes pasado", category: nil, amount: 250, method: .lastMonth),
            linea("Pago", category: nil, amount: 1500, method: .scheduled),
            linea("A mano", category: nil, amount: 80, method: .manual),
        ]

        let fijas = FlujoCrearPlanLogica.conLimiteFijo(lineas)

        #expect(fijas.map(\.estimationMethod) == [.manual, .manual, .manual, .scheduled, .manual])
        #expect(fijas.map(\.suggestedAmount) == [420, 300, 250, 1500, 80], "la cifra no cambia")
    }
}

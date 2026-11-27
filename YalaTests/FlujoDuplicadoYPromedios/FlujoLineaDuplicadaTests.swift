//
//  FlujoLineaDuplicadaTests.swift
//  YalaTests
//
//  Una línea del flujo de caja por cosa (encargo del 27-nov-2026, flujo de caja duplicado y promedios). «Lo mismo» es
//  lo que decide el motor al repartir cada movimiento: el mismo lado y el mismo pago planificado, la misma subcategoría o
//  la misma categoría sin subcategoría. Cada camino de alta se prueba aparte: «Agregar línea» (`addLine`, que usan
//  «Desde mis gastos», «Desde un pago planificado» y «Personalizada») y «Agregar a mi plan» desde «Otros»
//  (`promoteSubcategory` y `promoteFromOthers`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · una línea por cosa", .serialized)
struct FlujoLineaDuplicadaTests {

    // MARK: - Fixture

    private struct Escenario {
        let context: ModelContext
        let viewModel: CashFlowPlanViewModel
        let plan: CashFlowPlan
        /// Con dos subcategorías visibles: Supermercado y Mercado.
        let comida: YalaCategory
        let supermercado: Subcategory
        let mercado: Subcategory
        /// Sin subcategorías.
        let gimnasio: YalaCategory
    }

    private static func escenario() throws -> Escenario {
        let context = try makeTestContext()
        let comida = YalaCategory(name: "Comida", colorHex: "#000000", isIncome: false)
        let gimnasio = YalaCategory(name: "Gimnasio", colorHex: "#000000", isIncome: false)
        context.insert(comida)
        context.insert(gimnasio)
        let supermercado = Subcategory(name: "Supermercado", sortOrder: 0, category: comida)
        let mercado = Subcategory(name: "Mercado", sortOrder: 1, category: comida)
        context.insert(supermercado)
        context.insert(mercado)
        let plan = CashFlowPlan(name: "")
        context.insert(plan)
        try context.save()
        let viewModel = CashFlowPlanViewModel()
        viewModel.setContext(context)
        return Escenario(
            context: context, viewModel: viewModel, plan: plan, comida: comida, supermercado: supermercado,
            mercado: mercado, gimnasio: gimnasio
        )
    }

    private static func lineas(_ e: Escenario) -> [CashFlowLine] {
        (e.plan.lines ?? []).filter { !$0.isDeleted }
    }

    private static func lineas(_ e: Escenario, sub: Subcategory) -> Int {
        lineas(e).filter { $0.subcategory?.persistentModelID == sub.persistentModelID }.count
    }

    // MARK: - «Agregar línea»

    @Test("«Desde mis gastos»: la misma subcategoría dos veces deja una sola línea")
    func agregarLinea_mismaSubcategoria_unaSola() throws {
        let e = try Self.escenario()
        let primera = e.viewModel.addLine(
            CashFlowLine(name: "Supermercado", category: e.comida, subcategory: e.supermercado)
        )
        let segunda = e.viewModel.addLine(
            CashFlowLine(name: "Súper otra vez", sortOrder: 1, category: e.comida, subcategory: e.supermercado)
        )
        #expect(primera)
        #expect(!segunda)
        #expect(Self.lineas(e, sub: e.supermercado) == 1)
        #expect(Self.lineas(e).first?.name == "Supermercado", "La que queda es la primera.")
    }

    @Test("«Desde mis gastos»: la misma categoría sin subcategorías dos veces deja una sola línea")
    func agregarLinea_mismaCategoriaSinSubcategorias_unaSola() throws {
        let e = try Self.escenario()
        e.viewModel.addLine(CashFlowLine(name: "Gimnasio", category: e.gimnasio))
        e.viewModel.addLine(CashFlowLine(name: "Gym", sortOrder: 1, estimationMethod: .lastMonth, category: e.gimnasio))
        #expect(Self.lineas(e).count == 1)
    }

    @Test("Una subcategoría junto a otra de su misma categoría, o junto a la categoría entera, no es la misma cosa")
    func agregarLinea_otraSubcategoria_oLaCategoria_entran() throws {
        let e = try Self.escenario()
        #expect(e.viewModel.addLine(CashFlowLine(name: "Supermercado", category: e.comida, subcategory: e.supermercado)))
        #expect(e.viewModel.addLine(CashFlowLine(name: "Mercado", category: e.comida, subcategory: e.mercado)))
        #expect(e.viewModel.addLine(CashFlowLine(name: "Comida", category: e.comida)))
        #expect(Self.lineas(e).count == 3)
    }

    @Test("La misma subcategoría como ingreso es otro lado: no choca con la de gasto")
    func agregarLinea_otroLado_entra() throws {
        let e = try Self.escenario()
        e.viewModel.addLine(CashFlowLine(name: "Supermercado", category: e.comida, subcategory: e.supermercado))
        let ingreso = e.viewModel.addLine(
            CashFlowLine(name: "Reembolsos", isIncome: true, category: e.comida, subcategory: e.supermercado)
        )
        #expect(ingreso)
        #expect(Self.lineas(e, sub: e.supermercado) == 2)
    }

    @Test("«Personalizada»: sin categoría ni pago nunca choca, aunque se llame igual")
    func agregarLinea_personalizada_nuncaChoca() throws {
        let e = try Self.escenario()
        #expect(e.viewModel.addLine(CashFlowLine(name: "Ahorro", estimationMethod: .manual, manualAmount: 100)))
        #expect(e.viewModel.addLine(CashFlowLine(name: "Ahorro", estimationMethod: .manual, manualAmount: 100)))
        #expect(Self.lineas(e).count == 2)
    }

    @Test("Una línea que ya se borró no cuenta: la subcategoría vuelve a poder agregarse")
    func agregarLinea_trasBorrar_entra() throws {
        let e = try Self.escenario()
        e.viewModel.addLine(CashFlowLine(name: "Supermercado", category: e.comida, subcategory: e.supermercado))
        let primera = try #require(Self.lineas(e).first)
        e.viewModel.removeLine(primera)
        #expect(e.viewModel.addLine(CashFlowLine(name: "Supermercado", category: e.comida, subcategory: e.supermercado)))
        #expect(Self.lineas(e, sub: e.supermercado) == 1)
    }

    // MARK: - «Desde un pago planificado» (la regla, sin modelos)

    private static func linea(pagos: [UUID], esIngreso: Bool = false) -> FlujoMotorMes.Linea {
        FlujoMotorMes.Linea(id: UUID(), esIngreso: esIngreso, categoriaID: nil, subcategoriaID: nil, pagoIDs: pagos)
    }

    @Test("El mismo pago planificado en dos líneas de pagos choca; otro pago no")
    func pago_mismoPago_choca() {
        let alquiler = UUID()
        let luz = UUID()
        let existentes = [Self.linea(pagos: [alquiler])]
        #expect(FlujoLineasSinDuplicar.existente(para: Self.linea(pagos: [alquiler]), en: existentes) != nil)
        #expect(FlujoLineasSinDuplicar.existente(para: Self.linea(pagos: [luz]), en: existentes) == nil)
    }

    @Test("Una línea de varios pagos solo choca si todos tienen ya dueña (el motor se queda con el libre)")
    func pago_variosPagos_chocaSoloSiTodosTienenDueña() {
        let alquiler = UUID()
        let luz = UUID()
        let existentes = [Self.linea(pagos: [alquiler])]
        #expect(FlujoLineasSinDuplicar.existente(para: Self.linea(pagos: [alquiler, luz]), en: existentes) == nil)
        let ambas = existentes + [Self.linea(pagos: [luz])]
        #expect(FlujoLineasSinDuplicar.existente(para: Self.linea(pagos: [alquiler, luz]), en: ambas) != nil)
    }

    @Test("El mismo pago como ingreso y como gasto son dos lados distintos")
    func pago_otroLado_noChoca() {
        let pago = UUID()
        let existentes = [Self.linea(pagos: [pago], esIngreso: false)]
        #expect(FlujoLineasSinDuplicar.existente(para: Self.linea(pagos: [pago], esIngreso: true), en: existentes) == nil)
    }

    // MARK: - «Agregar a mi plan» desde «Otros»

    @Test("«Otros» › + de una subcategoría dos veces deja una sola línea")
    func otros_subcategoriaDosVeces_unaSola() throws {
        let e = try Self.escenario()
        e.viewModel.promoteSubcategory(e.supermercado, isIncome: false)
        e.viewModel.promoteSubcategory(e.supermercado, isIncome: false)
        #expect(Self.lineas(e, sub: e.supermercado) == 1)
    }

    @Test("«Otros» › + de una subcategoría que ya agregó «Agregar línea» no la repite")
    func otros_subcategoriaYaAgregada_noRepite() throws {
        let e = try Self.escenario()
        e.viewModel.addLine(CashFlowLine(name: "Súper", category: e.comida, subcategory: e.supermercado))
        e.viewModel.promoteSubcategory(e.supermercado, isIncome: false)
        #expect(Self.lineas(e, sub: e.supermercado) == 1)
    }

    @Test("«Otros» › + de una categoría sin subcategorías dos veces deja una sola línea")
    func otros_categoriaSinSubcategoriasDosVeces_unaSola() throws {
        let e = try Self.escenario()
        e.viewModel.promoteFromOthers(e.gimnasio)
        e.viewModel.promoteFromOthers(e.gimnasio)
        #expect(Self.lineas(e).count == 1)
    }

    @Test("«Otros» › + de una categoría con subcategorías agrega solo las que faltan")
    func otros_categoriaConSubcategorias_soloLasQueFaltan() throws {
        let e = try Self.escenario()
        e.viewModel.addLine(CashFlowLine(name: "Supermercado", category: e.comida, subcategory: e.supermercado))
        e.viewModel.promoteFromOthers(e.comida)
        #expect(Self.lineas(e, sub: e.supermercado) == 1)
        #expect(Self.lineas(e, sub: e.mercado) == 1)
        #expect(Self.lineas(e).count == 2)
    }

    // MARK: - La pregunta de «Desde mis gastos»

    @Test("«Desde mis gastos» pregunta si la fila ya está en el plan con la misma regla")
    func yaEnElPlan_mismaRegla() throws {
        let e = try Self.escenario()
        e.viewModel.addLine(CashFlowLine(name: "Supermercado", category: e.comida, subcategory: e.supermercado))
        e.viewModel.addLine(CashFlowLine(name: "Gimnasio", category: e.gimnasio))
        let lineas = Self.lineas(e)
        func ya(_ cat: YalaCategory, _ sub: Subcategory?, ingreso: Bool = false) -> Bool {
            FlujoLineasSinDuplicar.yaEnElPlan(categoria: cat, subcategoria: sub, esIngreso: ingreso, lineas: lineas)
        }
        #expect(ya(e.comida, e.supermercado))
        #expect(!ya(e.comida, e.mercado))
        #expect(ya(e.gimnasio, nil))
        #expect(!ya(e.gimnasio, nil, ingreso: true))
        #expect(!ya(e.comida, nil), "La categoría entera no es su subcategoría.")
    }
}

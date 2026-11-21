//
//  FlujoFluidezRecalculoTests.swift
//  YalaTests
//
//  Encargo de fluidez del 20-nov-2026: el Flujo de caja ya no recalcula la proyección cuando nada de lo que lee cambió
//  (volver a la pestaña, cerrar la hoja de una línea que solo se miró, volver de Registros), y la Comparativa no calcula
//  mientras no se ve. Estos casos fijan que los números no cambian y que el cálculo no se repite.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct FlujoFluidezRecalculoTests {

    private struct IdentityConverter: CurrencyConverting {
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal { amount }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal { amount }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
    }

    private static let dia = Date(timeIntervalSince1970: 1_790_000_000)

    /// Los guardados, como en la app: el recuento real del proceso (el cálculo puede guardar él mismo, y eso no cuenta).
    private func firma(revision: Int = 0, saves: Int? = nil, transacciones: Int = 3, divisa: String = "PEN") -> FlujoRecalculoFirma {
        FlujoRecalculoFirma(
            planRevision: revision, dataVersion: 0, storeSaves: saves ?? StoreSaveCounter.shared.count, transacciones: transacciones,
            pagosProgramados: 0, cuentas: 0, categorias: 0, currencyCode: divisa, includeGroups: true, dia: Self.dia
        )
    }

    private struct Escenario {
        let viewModel: CashFlowPlanViewModel
        let line: CashFlowLine
        let transactions: [TransactionItem]
        let context: ModelContext
    }

    private func escenario() throws -> Escenario {
        let context = try makeTestContext()
        let plan = CashFlowPlan(name: "", startingBalance: 1_000)
        context.insert(plan)
        let line = CashFlowLine(name: "Gimnasio", estimationMethod: .manual, manualAmount: 150)
        context.insert(line)
        line.plan = plan
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        var transactions: [TransactionItem] = []
        for (offset, amount) in [(-40, -120.0), (-10, -80.0), (1, 2_500.0)] {
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let item = TransactionItem(date: date, amount: amount, currencyCode: "PEN")
            context.insert(item)
            transactions.append(item)
        }
        try context.save()
        let viewModel = CashFlowPlanViewModel()
        viewModel.setContext(context)
        return Escenario(viewModel: viewModel, line: line, transactions: transactions, context: context)
    }

    private func recalcular(_ e: Escenario, firma: FlujoRecalculoFirma?) {
        e.viewModel.recalculate(
            transactions: e.transactions, allExpenseCategories: [], scheduledPayments: [],
            currencyCode: "PEN", converter: IdentityConverter(), firma: firma
        )
    }

    /// Lo que se ve de cada mes: si dos proyecciones dan esto igual, la pantalla enseña los mismos números.
    private func cifras(_ viewModel: CashFlowPlanViewModel) -> [String] {
        (viewModel.projection?.months ?? []).map {
            "\($0.monthKey)|\($0.totalIncome)|\($0.totalExpense)|\($0.netFlow)|\($0.accumulatedBalance ?? -1)"
        }
    }

    // MARK: - El cálculo no se repite

    @Test func mismaFirma_noRepiteElCalculo_yLasCifrasSiguenIguales() throws {
        let e = try escenario()
        recalcular(e, firma: firma())
        let primeras = cifras(e.viewModel)
        #expect(e.viewModel.proyeccionesCalculadas == 1)
        #expect(!primeras.isEmpty)

        // Volver a la pestaña, cerrar la hoja de una línea, volver de Registros: la misma firma.
        recalcular(e, firma: firma())
        recalcular(e, firma: firma())

        #expect(e.viewModel.proyeccionesCalculadas == 1)
        #expect(cifras(e.viewModel) == primeras)
    }

    @Test func cadaCambioDeLaFirma_recalcula() throws {
        let e = try escenario()
        recalcular(e, firma: firma())
        recalcular(e, firma: firma(revision: 1))
        recalcular(e, firma: firma(revision: 1, saves: -4))
        recalcular(e, firma: firma(revision: 1, saves: -4, transacciones: 2))
        recalcular(e, firma: firma(revision: 1, saves: -4, transacciones: 2, divisa: "USD"))
        #expect(e.viewModel.proyeccionesCalculadas == 5)
    }

    /// Una línea cambiada en el contexto y aún sin guardar no cambia la firma: los cambios pendientes obligan igual.
    @Test func cambioSinGuardar_recalculaAunqueLaFirmaSeaLaMisma() throws {
        let e = try escenario()
        recalcular(e, firma: firma())
        let antes = cifras(e.viewModel)

        e.line.manualAmount = 900
        #expect(e.context.hasChanges)
        recalcular(e, firma: firma())

        #expect(e.viewModel.proyeccionesCalculadas == 2)
        #expect(cifras(e.viewModel) != antes)
        e.context.rollback()
    }

    // MARK: - Los números no cambian

    /// La proyección que sale por el camino con firma es la misma que la que se calcula siempre (sin firma).
    @Test func conFirmaYSinFirma_danLasMismasCifras() throws {
        let conFirma = try escenario()
        recalcular(conFirma, firma: firma())
        let a = cifras(conFirma.viewModel)
        recalcular(conFirma, firma: nil)
        let b = cifras(conFirma.viewModel)
        #expect(a == b)
        #expect(conFirma.viewModel.proyeccionesCalculadas == 2, "Sin firma se calcula siempre.")
    }

    @Test func sinPlan_noHayProyeccion_yLaFirmaSeOlvida() throws {
        let e = try escenario()
        recalcular(e, firma: firma())
        e.viewModel.resetPlan()
        recalcular(e, firma: firma())
        #expect(e.viewModel.projection == nil)
    }
}

/// La regla pura: cuándo recalcula el Flujo de caja y cuándo la Comparativa.
@Suite
struct FlujoFluidezLogicaTests {

    private static let hoy = Date(timeIntervalSince1970: 1_790_000_000)
    private static let manana = hoy.addingTimeInterval(86_400)

    private func firma(saves: Int = 0, dia: Date = hoy) -> FlujoRecalculoFirma {
        FlujoRecalculoFirma(
            planRevision: 0, dataVersion: 0, storeSaves: saves, transacciones: 10, pagosProgramados: 1, cuentas: 2,
            categorias: 5, currencyCode: "PEN", includeGroups: true, dia: dia
        )
    }

    @Test func flujo_sinCalculoPrevio_calcula() {
        #expect(FlujoFluidezLogica.flujoDebeRecalcular(ultima: nil, actual: firma(), hayProyeccion: false, hayCambiosSinGuardar: false))
        #expect(FlujoFluidezLogica.flujoDebeRecalcular(ultima: firma(), actual: firma(), hayProyeccion: false, hayCambiosSinGuardar: false))
    }

    @Test func flujo_mismaFirma_noCalcula() {
        #expect(!FlujoFluidezLogica.flujoDebeRecalcular(ultima: firma(), actual: firma(), hayProyeccion: true, hayCambiosSinGuardar: false))
    }

    @Test func flujo_unGuardadoOElDiaSiguiente_calcula() {
        #expect(FlujoFluidezLogica.flujoDebeRecalcular(ultima: firma(), actual: firma(saves: 1), hayProyeccion: true, hayCambiosSinGuardar: false))
        #expect(FlujoFluidezLogica.flujoDebeRecalcular(ultima: firma(), actual: firma(dia: Self.manana), hayProyeccion: true, hayCambiosSinGuardar: false))
    }

    @Test func flujo_cambiosSinGuardar_calcula() {
        #expect(FlujoFluidezLogica.flujoDebeRecalcular(ultima: firma(), actual: firma(), hayProyeccion: true, hayCambiosSinGuardar: true))
    }

    @Test func comparativa_pendiente_calcula() {
        #expect(FlujoFluidezLogica.comparativaDebeCalcular(
            pendiente: true, guardadosVistos: 3, guardadosAhora: 3, diaVisto: Self.hoy, diaAhora: Self.hoy
        ))
    }

    @Test func comparativa_alDia_noCalcula() {
        #expect(!FlujoFluidezLogica.comparativaDebeCalcular(
            pendiente: false, guardadosVistos: 3, guardadosAhora: 3, diaVisto: Self.hoy, diaAhora: Self.hoy
        ))
    }

    @Test func comparativa_unaEdicionEnSitioOOtroDia_calcula() {
        #expect(FlujoFluidezLogica.comparativaDebeCalcular(
            pendiente: false, guardadosVistos: 3, guardadosAhora: 4, diaVisto: Self.hoy, diaAhora: Self.hoy
        ))
        #expect(FlujoFluidezLogica.comparativaDebeCalcular(
            pendiente: false, guardadosVistos: 3, guardadosAhora: 3, diaVisto: Self.hoy, diaAhora: Self.manana
        ))
        #expect(FlujoFluidezLogica.comparativaDebeCalcular(
            pendiente: false, guardadosVistos: nil, guardadosAhora: 0, diaVisto: nil, diaAhora: Self.hoy
        ))
    }
}
